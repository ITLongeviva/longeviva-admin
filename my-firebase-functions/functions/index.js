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
