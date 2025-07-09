L'obiettivo è prendere il tuo codice Node.js, trasformarlo in una Firebase Cloud Function e poi invocare quella funzione con una richiesta HTTP per creare il tuo utente admin. Questo aggirerà il problema dell' invalid_grant perché la Cloud Function si autenticherà automaticamente usando un account di servizio di Google Cloud, senza bisogno di chiavi private sul tuo computer.
Ecco la guida completa:
Guida Passo Passo: Creare Admin con Cloud Function

Passo 0: Prerequisiti (Da fare solo la prima volta)

Installa Node.js: Se non l'hai già, scarica e installa Node.js (versione LTS consigliata) dal sito ufficiale: nodejs.org . Questo include anche npm .
Installa Firebase CLI: Apri il tuo terminale (o Prompt dei comandi su Windows) ed esegui questo comando:
npm install -g firebase-tools
Accedi a Firebase: Nel tuo terminale, esegui:
firebase login
Si aprirà una finestra del browser. Accedi con il tuo account Google che ha accesso al progetto Firebase longeviva-web-app-dev . Consenti a Firebase CLI di gestire i tuoi progetti.
Inizializza il tuo Progetto Firebase per le Functions:
Crea una nuova cartella per il tuo progetto Cloud Functions (es. my-firebase-functions ) e entra al suo interno:
mkdir my-firebase-functions
cd my-firebase-functions
Inizializza Firebase Functions:
firebase init functions
Ti verrà chiesto:
"Which project would you like to use?": Seleziona il tuo progetto longeviva-web-app-dev .
"What language would you like to use to develop your functions?": Seleziona JavaScript .
"Do you want to use ESLint to catch probable bugs and enforce style?": Puoi scegliere No per semplicità o Yes se preferisci un controllo del codice.
"Do you want to install dependencies with npm now?": Scegli Yes .
Questo creerà una sottocartella functions all'interno di my-firebase-functions con i file necessari ( index.js , package.json , ecc.).
Passo 1: Adatta il Codice per la Cloud Function

Dobbiamo modificare il tuo createAdmin.js per farlo funzionare come una Cloud Function. Le funzioni Cloud non hanno un'interfaccia a riga di comando ( readline ) e ricevono i dati tramite richieste HTTP.
Entra nella cartella functions :
cd functions
Apri il file index.js : Questo è il file principale delle tue Cloud Functions. Sovrascrivi il contenuto di index.js con il seguente codice:
// functions/index.js

const admin = require('firebase-admin');
const functions = require('firebase-functions'); // Importa il modulo di Firebase Functions

// Inizializza Firebase Admin.
// NESSUN argomento qui! Le credenziali verranno fornite automaticamente
// dall'ambiente della Cloud Function. Questa è la magia!
admin.initializeApp();

const auth = admin.auth();
const db = admin.firestore();

// Definisci la tua Cloud Function. La esporteremo come 'createAdminUser'.
// Questa funzione sarà attivata da una richiesta HTTP (POST).
exports.createAdminUser = functions.https.onRequest(async (req, res) => {
// 1. Controlla il metodo HTTP: Solo richieste POST sono permesse per sicurezza.
if (req.method !== 'POST') {
// Se non è POST, restituisci un errore 405 (Method Not Allowed)
console.warn('Metodo HTTP non consentito:', req.method);
return res.status(405).send('Metodo non consentito. Usa POST.');
}

// 2. Ottieni i dati dall'input: Le Cloud Functions HTTP ricevono i dati nel corpo della richiesta.
// Ci aspettiamo un JSON con name, email e password.
const { name, email, password } = req.body;

try {
// 3. Validazione base dei dati (come nel tuo script originale)
if (!name || !email || !password) {
throw new Error('Tutti i campi (name, email, password) sono obbligatori.');
}
if (password.length < 8) {
throw new Error('La password deve essere almeno 8 caratteri.');
}
if (!email.includes('@')) {
throw new Error('Email non valida.');
}

    console.log(`Inizio creazione admin per: ${email}`); // Log utile per il debugging in Cloud Logs

    // 4. Crea utente in Firebase Auth (il tuo codice originale, che ora funzionerà!)
    const userRecord = await auth.createUser({
      email: email.trim(),
      password: password,
      displayName: name.trim(),
      emailVerified: true
    });
    console.log('Utente creato con UID:', userRecord.uid);

    // 5. Imposta custom claims per l'admin
    await auth.setCustomUserClaims(userRecord.uid, {
      admin: true,
      role: 'ADMIN'
    });
    console.log('Permessi admin assegnati');

    // 6. Crea profilo in admin_profiles e admins collection usando una batch write per efficienza
    const batch = db.batch();
    batch.set(db.collection('admin_profiles').doc(userRecord.uid), {
      name: name.trim(),
      email: email.trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      role: 'ADMIN'
    });
    batch.set(db.collection('admins').doc(userRecord.uid), {
      id: userRecord.uid,
      name: name.trim(),
      email: email.trim(),
      password: '', // Non salviamo la password in chiaro
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    await batch.commit();
    console.log('Profili Firestore creati/aggiornati');

    // 7. Risposta di successo: Invia una risposta JSON al chiamante.
    console.log('Admin creato con successo!');
    res.status(200).json({
      message: 'Admin creato con successo!',
      uid: userRecord.uid,
      email: email,
      name: name
    });

} catch (error) {
// 8. Gestione degli errori: Cattura e rispondi con un messaggio di errore.
console.error('Errore durante la creazione admin:', error); // Log l'errore completo per il debugging
let errorMessage = 'Errore sconosciuto durante la creazione admin.';
let statusCode = 500; // Internal Server Error di default

    // Gestione errori specifici di Firebase Auth per messaggi più chiari
    if (error.code) {
      switch (error.code) {
        case 'auth/email-already-exists':
          errorMessage = 'L\'email specificata è già registrata nel sistema.';
          statusCode = 409; // Conflict
          break;
        case 'auth/invalid-email':
          errorMessage = 'L\'email specificata non è valida.';
          statusCode = 400; // Bad Request
          break;
        case 'auth/weak-password':
          errorMessage = 'La password è troppo debole (min. 6 caratteri per Firebase Auth).';
          statusCode = 400; // Bad Request
          break;
        case 'auth/operation-not-allowed':
          errorMessage = 'La creazione di account email/password non è abilitata per il tuo progetto. Abilitale nella console Firebase sotto "Authentication" -> "Sign-in method".';
          statusCode = 403; // Forbidden
          break;
        default:
          errorMessage = `Errore Firebase Auth: ${error.message}`;
          statusCode = 500;
      }
    } else {
      // Errori di validazione o altri errori generici dal tuo codice
      errorMessage = error.message;
      statusCode = 400; // Bad Request
    }

    // Invia la risposta di errore al chiamante
    res.status(statusCode).json({ error: errorMessage });
}
});
Espandi
Verifica package.json : Assicurati che il tuo file package.json (che si trova nella stessa cartella functions ) abbia queste dipendenze. Dovrebbero essere già state installate se hai seguito il Passo 0.
{
"name": "functions",
"description": "Cloud Functions for Firebase",
"scripts": {
"serve": "firebase emulators:start --only functions",
"shell": "firebase functions:shell",
"start": "npm run shell",
"deploy": "firebase deploy --only functions",
"logs": "firebase functions:log"
},
"engines": {
"node": "20"  // Assicurati che sia 20 o una versione supportata da Firebase
},
"main": "index.js",
"dependencies": {
"firebase-admin": "^12.0.0",   // Versione attuale o più recente
"firebase-functions": "^5.0.0" // Versione attuale o più recente
},
"devDependencies": {
"firebase-functions-test": "^3.1.0"
},
"private": true
}
Espandi
Installa le dipendenze (se hai modificato package.json ): Nel terminale, assicurati di essere nella cartella functions ed esegui:
npm install
Passo 2: Esegui il Deploy della Cloud Function

Ora che il codice è pronto, lo caricheremo su Firebase.
Assicurati di essere nella cartella functions :
cd my-firebase-functions/functions
Esegui il deploy:
firebase deploy --only functions:createAdminUser
Questo comando caricherà il tuo codice sul cloud.
L'operazione potrebbe richiedere qualche minuto.
Alla fine, vedrai un output che include l'URL della tua funzione HTTP. Sarà qualcosa del tipo: Function URL (createAdminUser): https://REGION-PROJECT_ID.cloudfunctions.net/createAdminUser Copia questo URL , ne avrai bisogno per il prossimo passo!
Passo 3: Invia una Richiesta POST per Creare l'Account Admin

Ora che la tua funzione è deployata, puoi inviare una richiesta HTTP per attivarla.
Informazioni importanti:
La richiesta deve essere di tipo POST .
Il corpo della richiesta deve essere in formato JSON .
Il JSON deve contenere i campi name , email e password .
Ci sono diversi modi per fare una richiesta POST. Ne vediamo due comuni:
Opzione A: Usando curl (da Terminale/Prompt dei comandi)
curl è uno strumento da riga di comando per fare richieste HTTP. È ottimo per test rapidi.
Apri un nuovo terminale (non quello dove hai fatto il deploy).
Sostituisci YOUR_FUNCTION_URL con l'URL che hai copiato al Passo 2.
Sostituisci Nome Admin , email@esempio.com e passwordadmin123 con i dati reali del tuo nuovo admin.
curl -X POST -H "Content-Type: application/json" -d '{ "name": "Nome Admin di Prova", "email": "email.admin@tuodominio.com", "password": "passwordAdminSicura123" }' YOUR_FUNCTION_URL
(Nota per Windows: Potresti aver bisogno di usare virgolette doppie per l'intero JSON e virgolette singole all'interno, o scappare le virgolette interne con un backslash. Es: "{ \"name\": \"...\" }" )
Opzione B: Usando un Tool Grafico (es. Postman, Insomnia, o anche estensioni browser)
Questi tool offrono un'interfaccia utente più comoda per costruire e inviare richieste HTTP.
Scarica e installa uno di questi tool (es. Postman).
Crea una nuova richiesta:
Imposta il metodo su POST .
Nel campo URL, incolla la YOUR_FUNCTION_URL che hai copiato al Passo 2.
Vai alla sezione "Headers" (intestazioni) e aggiungi una nuova intestazione:
Key: Content-Type
Value: application/json
Vai alla sezione "Body" (corpo della richiesta):
Seleziona il tipo "raw" e il formato "JSON".
Incolla il seguente JSON, sostituendo i dati di esempio con quelli reali:
{
"name": "Nome Admin di Prova",
"email": "email.admin@tuodominio.com",
"password": "passwordAdminSicura123"
}
Espandi
Clicca su "Send" (Invia).
Cosa ti aspetti come risposta:
Successo (status 200 OK):
{
"message": "Admin creato con successo!",
"uid": "L'UID dell'utente creato",
"email": "email.admin@tuodominio.com",
"name": "Nome Admin di Prova"
}
Espandi
Errore (status 4xx o 5xx):
{
"error": "Messaggio di errore che indica cosa è andato storto (es. email già usata, password debole, validazione fallita)"
}
Espandi
Come verificare il risultato in Firebase Console:
Vai alla console Firebase del tuo progetto longeviva-web-app-dev .
Naviga su Build -> Authentication . Nella scheda "Users", dovresti vedere il nuovo utente creato con l'email che hai fornito.
Naviga su Build -> Firestore Database . Cerca le collezioni admin_profiles e admins . Dovresti trovare i nuovi documenti creati per il tuo utente admin.
Per vedere i log della tua Cloud Function (per debugging), vai su Build -> Functions e clicca sulla tab "Logs" per la funzione createAdminUser .
Spero che questa guida passo passo sia molto più chiara! Fammi sapere come va, e se incontri altri ostacoli, sono qui!