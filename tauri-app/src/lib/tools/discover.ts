import type { ToolDefinition } from "./types";

// sveltekit: import.meta.glob(eager:true) auto-imports every matching file at build time --
// adding a tool to the home grid is just adding a tool.ts file next to a feature's other
// files, no central import list to maintain (mirrors the old feature-registry glob pattern,
// see docs/legacy-frontend.md, minus the parts of it that never actually got used)
const modules = import.meta.glob<{ default: ToolDefinition }>("$lib/features/**/tool.ts", { eager: true });

export const tools: ToolDefinition[] = Object.values(modules).map((module) => module.default);
