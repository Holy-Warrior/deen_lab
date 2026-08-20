import { BellOff } from "@lucide/svelte";
import type { ToolDefinition } from "$lib/tools/types";

export default {
    id: "auto-silent",
    name: "Auto Silent",
    description: "Silence your phone during salah",
    icon: BellOff,
    route: "/auto-silent"
} satisfies ToolDefinition;
