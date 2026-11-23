// First, so its settings apply to every function below.
import "./options";

import {initializeApp} from "firebase-admin/app";

export {requestAccountDeletion, restoreAccount} from "./accountDeletion";
export {janitor} from "./janitor";

initializeApp();
