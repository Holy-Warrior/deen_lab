package com.holywarrior.silence_of_salah_engine.ml_inference

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.exp

object XGBoostInference {

    @Volatile
    private var forest: NativeForest? = null

    @Volatile
    private var numFeatures: Int = 0

    private val isLoaded = AtomicBoolean(false)

    fun loadSafely(modelPath: String, windowSize: Int = 150): Boolean {
        return try {
            load(modelPath, windowSize)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            forest = null
            isLoaded.set(false)
            false
        }
    }

    fun load(modelPath: String, windowSize: Int = 150) {
        require(File(modelPath).exists()) { "Model file not found: $modelPath" }

        val json = File(modelPath).readText()
        val root = JSONObject(json)
        val parsedForest = NativeForest.fromJson(root)

        synchronized(this) {
            forest = parsedForest
            numFeatures = windowSize * NUM_CHANNELS
            require(parsedForest.numFeatures == numFeatures) {
                "Model expects ${parsedForest.numFeatures} features but task produces $numFeatures"
            }
            isLoaded.set(true)
        }
    }

    fun isLoaded(): Boolean = isLoaded.get()

    fun dispose() {
        synchronized(this) {
            forest = null
            isLoaded.set(false)
        }
    }

    fun predictOrNull(features: FloatArray): PredictionResult? {
        val activeForest = forest ?: return null

        return try {
            if (features.size != numFeatures) return null

            val margin = activeForest.baseMargin + activeForest.trees.sumOf {
                it.evaluate(features).toDouble()
            }.toFloat()
            val probability = sigmoid(margin)
            val label = if (probability >= THRESHOLD) 1 else 0

            PredictionResult(label, probability)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    var THRESHOLD: Float = 0.5f

    private fun sigmoid(value: Float): Float {
        return (1.0 / (1.0 + exp(-value.toDouble()))).toFloat()
    }

    data class PredictionResult(val label: Int, val probability: Float) {
        val isNimaz: Boolean
            get() = label == 1
    }

    private data class NativeForest(
        val numFeatures: Int,
        val baseMargin: Float,
        val trees: List<TreeNode>
    ) {
        companion object {
            fun fromJson(root: JSONObject): NativeForest {
                val treesArray = root.getJSONArray("trees")
                val trees = buildList(treesArray.length()) {
                    for (index in 0 until treesArray.length()) {
                        add(TreeNode.fromJson(treesArray.getJSONObject(index)))
                    }
                }

                return NativeForest(
                    numFeatures = root.getInt("numFeatures"),
                    baseMargin = root.getDouble("baseMargin").toFloat(),
                    trees = trees
                )
            }
        }
    }

    private sealed interface TreeNode {
        fun evaluate(features: FloatArray): Float

        companion object {
            fun fromJson(node: JSONObject): TreeNode {
                if (node.has("leaf")) {
                    return LeafNode(node.getDouble("leaf").toFloat())
                }

                val childrenById = mutableMapOf<Int, TreeNode>()
                val childrenJson = node.getJSONArray("children")
                for (index in 0 until childrenJson.length()) {
                    val childJson = childrenJson.getJSONObject(index)
                    childrenById[childJson.getInt("nodeid")] = fromJson(childJson)
                }

                return DecisionNode(
                    featureIndex = node.getString("split").removePrefix("f").toInt(),
                    threshold = node.getDouble("split_condition").toFloat(),
                    yesNodeId = node.getInt("yes"),
                    noNodeId = node.getInt("no"),
                    missingNodeId = node.getInt("missing"),
                    children = childrenById
                )
            }
        }
    }

    private data class DecisionNode(
        val featureIndex: Int,
        val threshold: Float,
        val yesNodeId: Int,
        val noNodeId: Int,
        val missingNodeId: Int,
        val children: Map<Int, TreeNode>
    ) : TreeNode {
        override fun evaluate(features: FloatArray): Float {
            val value = features[featureIndex]
            val nextNodeId = when {
                value.isNaN() -> missingNodeId
                value < threshold -> yesNodeId
                else -> noNodeId
            }

            return children.getValue(nextNodeId).evaluate(features)
        }
    }

    private data class LeafNode(
        val value: Float
    ) : TreeNode {
        override fun evaluate(features: FloatArray): Float = value
    }

    private const val NUM_CHANNELS = 3
}
