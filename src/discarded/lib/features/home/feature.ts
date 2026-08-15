import { defineFeature } from "$lib/ui";

export default defineFeature({

    id: "home",

    name: "Home",

    navigation: [

        {

            id: "home",

            name: "Workspace",

            page: "home",

            icon: "house",

            location: "center"

        }

    ],

    sections: [

        {

            id: "knowledge",

            title: "Knowledge",

            view: "grid",

            source: {

                collections: [

                    "knowledge"

                ]

            }

        },

        {

            id: "generated",

            title: "Generated",

            view: "grid",

            source: {

                collections: [

                    "generated"

                ]

            }

        }

    ],

    tools: [

        {

            id: "feature-studio",

            name: "Feature Studio",

            description: "Create small Deen-focused tools with AI",

            icon: "sparkles",

            route: "/feature-studio",

            collections: [

                "generated"

            ]

        },

        {

            id: "duas",

            name: "Duas",

            description: "Authentic supplications for daily life",

            icon: "heart",

            route: "/duas",

            collections: [

                "knowledge"

            ]

        },

        {

            id: "hadith",

            name: "Hadith",

            description: "Browse and search Hadith collections",

            icon: "library",

            route: "/hadith",

            collections: [

                "knowledge"

            ]

        },

        {

            id: "sehri-iftari",

            name: "Sehri & Iftari",

            description: "Fasting times and monthly calendar",

            icon: "calendar",

            route: "/sehri-iftari",

            collections: [

                "knowledge"

            ]

        },

        {

            id: "prayer-times",

            name: "Prayer Times",

            description: "Daily salah timings and next prayer",

            icon: "clock",

            route: "/prayer-times",

            collections: [

                "knowledge"

            ]

        },

        {

            id: "qibla",

            name: "Qibla",

            description: "Find the direction of the Kaaba",

            icon: "compass",

            route: "/qibla",

            collections: [

                "knowledge"

            ]

        }

    ],

    pages: [

        {

            id: "home",

            title: "Workspace",

            sections: [

                "knowledge",

                "generated"

            ]

        }

    ]

});
