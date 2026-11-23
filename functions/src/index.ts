import {initializeApp} from "firebase-admin/app";

export {requestAccountDeletion, restoreAccount} from "./accountDeletion";
export {janitor} from "./janitor";
export {onAccountDeletionChanged} from "./accountMail";

// Initialize Firebase Admin
initializeApp();
