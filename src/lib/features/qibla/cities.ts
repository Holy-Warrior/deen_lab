import type { Coordinates } from "./service";

export interface City extends Coordinates {
    name: string;
    country: string;
}

// design: shown whenever a real position can't be resolved -- deliberately far from Pakistan
// (unlike the old Peshawar default) so a real GPS fix is obviously different from the fallback
// instead of looking identical to it when testing from that region.
export const fallbackLocation: City = { name: "Sydney", country: "Australia", latitude: -33.8688, longitude: 151.2093 };

// design: manual fallback for the "GPS isn't usable at all" case (permission denied, or no
// location capability on the device) -- a small curated list rather than a geocoding API call.
export const cities: City[] = [
    { name: "Mecca", country: "Saudi Arabia", latitude: 21.4225, longitude: 39.8262 },
    { name: "Medina", country: "Saudi Arabia", latitude: 24.4672, longitude: 39.6111 },
    { name: "Riyadh", country: "Saudi Arabia", latitude: 24.7136, longitude: 46.6753 },
    { name: "Jeddah", country: "Saudi Arabia", latitude: 21.4858, longitude: 39.1925 },
    { name: "Dubai", country: "UAE", latitude: 25.2048, longitude: 55.2708 },
    { name: "Abu Dhabi", country: "UAE", latitude: 24.4539, longitude: 54.3773 },
    { name: "Doha", country: "Qatar", latitude: 25.2854, longitude: 51.5310 },
    { name: "Amman", country: "Jordan", latitude: 31.9454, longitude: 35.9284 },
    { name: "Baghdad", country: "Iraq", latitude: 33.3152, longitude: 44.3661 },
    { name: "Cairo", country: "Egypt", latitude: 30.0444, longitude: 31.2357 },
    { name: "Istanbul", country: "Turkey", latitude: 41.0082, longitude: 28.9784 },
    { name: "Karachi", country: "Pakistan", latitude: 24.8607, longitude: 67.0011 },
    { name: "Lahore", country: "Pakistan", latitude: 31.5497, longitude: 74.3436 },
    { name: "Islamabad", country: "Pakistan", latitude: 33.6844, longitude: 73.0479 },
    { name: "Peshawar", country: "Pakistan", latitude: 34.0151, longitude: 71.5249 },
    { name: "Quetta", country: "Pakistan", latitude: 30.1798, longitude: 66.9750 },
    { name: "Dhaka", country: "Bangladesh", latitude: 23.8103, longitude: 90.4125 },
    { name: "Jakarta", country: "Indonesia", latitude: -6.2088, longitude: 106.8456 },
    { name: "Kuala Lumpur", country: "Malaysia", latitude: 3.1390, longitude: 101.6869 },
    { name: "London", country: "United Kingdom", latitude: 51.5072, longitude: -0.1276 },
    { name: "New York", country: "United States", latitude: 40.7128, longitude: -74.0060 },
    { name: "Toronto", country: "Canada", latitude: 43.6532, longitude: -79.3832 },
    { name: "Sydney", country: "Australia", latitude: -33.8688, longitude: 151.2093 }
];
