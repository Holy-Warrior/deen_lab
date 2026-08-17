import { BookOpenText } from "@lucide/svelte";
import type { ToolDefinition } from "$lib/tools/types";

export default {
    id: "quran",
    name: "Quran",
    description: "Read with translation and transliteration",
    icon: BookOpenText,
    route: "/quran"
} satisfies ToolDefinition;
