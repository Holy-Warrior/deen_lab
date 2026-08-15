import type { Backend } from "./backend";

export class MockBackend
    implements Backend {

    async initialize() {

        console.info(

            "[MockBackend] initialized"

        );

    }

}
