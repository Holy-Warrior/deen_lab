import type { ToolDefinition } from "$lib/tools/types";

// sveltekit: mirrors $lib/tools/discover.ts's glob-based registration, but looks for
// library.ts instead of tool.ts -- a feature registers a tile on Home (quick, time-sensitive
// actions like Qibla/Sehri & Iftari), a tile in the Library tab (reference/reading content like
// Duas), both, or neither, just by which marker file it drops next to its other files.
const modules = import.meta.glob<{ default: ToolDefinition }>("$lib/features/**/library.ts", { eager: true });

export const libraryEntries: ToolDefinition[] = Object.values(modules).map((module) => module.default);
