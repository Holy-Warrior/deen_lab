export interface Coordinates {
    latitude: number;
    longitude: number;
}

export interface QiblaDirection extends Coordinates {
    degrees: number;
    label: string;
}

const makkah: Coordinates = { latitude: 21.4225, longitude: 39.8262 };
export const peshawar: Coordinates = { latitude: 34.0151, longitude: 71.5249 };

function radians(value: number) { return value * Math.PI / 180; }
function degrees(value: number) { return value * 180 / Math.PI; }

export function qiblaDirection(coordinates: Coordinates): QiblaDirection {
    const latitude = radians(coordinates.latitude);
    const longitudeDifference = radians(makkah.longitude - coordinates.longitude);
    const makkahLatitude = radians(makkah.latitude);
    const y = Math.sin(longitudeDifference) * Math.cos(makkahLatitude);
    const x = Math.cos(latitude) * Math.sin(makkahLatitude) -
        Math.sin(latitude) * Math.cos(makkahLatitude) * Math.cos(longitudeDifference);
    const bearing = (degrees(Math.atan2(y, x)) + 360) % 360;
    const labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];

    return {
        ...coordinates,
        degrees: bearing,
        label: labels[Math.round(bearing / 45) % labels.length]
    };
}

export function currentCoordinates(): Promise<Coordinates> {
    return new Promise((resolve, reject) => {
        if (!navigator.geolocation) {
            reject(new Error("Location is not available on this device."));
            return;
        }

        navigator.geolocation.getCurrentPosition(
            position => resolve({ latitude: position.coords.latitude, longitude: position.coords.longitude }),
            () => reject(new Error("Location access was not granted.")),
            { enableHighAccuracy: true, timeout: 10_000, maximumAge: 300_000 }
        );
    });
}
