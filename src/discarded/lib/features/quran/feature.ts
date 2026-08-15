import { defineFeature } from "$lib/ui";

export default defineFeature({

    id: "quran",

    name: "Quran",

    tools: [

        {

            id: "quran",

            name: "Quran",

            description: "Read the Holy Quran",

            icon: "book-open",

            route: "/quran",

            collections: [

                "knowledge"

            ]

        }

    ]

});
