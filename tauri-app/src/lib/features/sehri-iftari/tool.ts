import { Calendar } from "@lucide/svelte";
import type { ToolDefinition } from "$lib/tools/types";

export default {
    id: "sehri-iftari",
    name: "Sehri & Iftari",
    description: "Fasting times and monthly calendar",
    icon: Calendar,
    route: "/sehri-iftari"
} satisfies ToolDefinition;
