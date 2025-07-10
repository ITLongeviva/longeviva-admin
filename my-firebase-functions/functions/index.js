// functions/index.js
const admin = require('firebase-admin');
// IMPORTANTE: Importa da v2/https per Gen 2
const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');

// Inizializza Firebase Admin
admin.initializeApp();

const auth = admin.auth();
const db = admin.firestore();

// Imposta opzioni globali (opzionale)
setGlobalOptions({
  region: 'us-central1', // o la tua regione preferita
  maxInstances: 10,
});

// Definisci la funzione Gen 2 con configurazione
exports.createAdminUser = onRequest({
  // Configurazioni Gen 2
  cors: true, // Abilita CORS automaticamente
  maxInstances: 10,
  minInstances: 0,
  concurrency: 80, // Vantaggio di Gen 2 - gestisce più richieste per istanza

  // IMPORTANTE: Per controllare chi può invocare la funzione
  // Opzioni:
  // - Non specificare nulla = pubblico di default
  // - invoker: "private" = solo service account autorizzati
  // - invoker: ["user:email@example.com"] = utenti specifici

  // Per ora lascialo pubblico per il deploy iniziale
  // Poi potrai configurarlo come privato
}, async (req, res) => {

  // CORS è già gestito da Gen 2 con l'opzione cors: true

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    console.warn('Metodo HTTP non consentito:', req.method);
    return res.status(405).send('Metodo non consentito. Usa POST.');
  }

  const { name, email, password } = req.body;

  try {
    // Validazione
    if (!name || !email || !password) {
      throw new Error('Tutti i campi (name, email, password) sono obbligatori.');
    }
    if (password.length < 8) {
      throw new Error('La password deve essere almeno 8 caratteri.');
    }
    if (!email.includes('@')) {
      throw new Error('Email non valida.');
    }

    console.log(`Inizio creazione admin per: ${email}`);

    // Crea utente
    const userRecord = await auth.createUser({
      email: email.trim(),
      password: password,
      displayName: name.trim(),
      emailVerified: true
    });
    console.log('Utente creato con UID:', userRecord.uid);

    // Imposta custom claims
    await auth.setCustomUserClaims(userRecord.uid, {
      admin: true,
      role: 'ADMIN'
    });
    console.log('Permessi admin assegnati');

    // Crea profili in Firestore
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
      password: '', // Mai salvare password in chiaro
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    await batch.commit();
    console.log('Profili Firestore creati/aggiornati');

    console.log('Admin creato con successo!');
    res.status(200).json({
      message: 'Admin creato con successo!',
      uid: userRecord.uid,
      email: email,
      name: name
    });

  } catch (error) {
    console.error('Errore durante la creazione admin:', error);
    let errorMessage = 'Errore sconosciuto durante la creazione admin.';
    let statusCode = 500;

    if (error.code) {
      switch (error.code) {
        case 'auth/email-already-exists':
          errorMessage = 'L\'email specificata è già registrata nel sistema.';
          statusCode = 409;
          break;
        case 'auth/invalid-email':
          errorMessage = 'L\'email specificata non è valida.';
          statusCode = 400;
          break;
        case 'auth/weak-password':
          errorMessage = 'La password è troppo debole (min. 6 caratteri per Firebase Auth).';
          statusCode = 400;
          break;
        case 'auth/operation-not-allowed':
          errorMessage = 'La creazione di account email/password non è abilitata.';
          statusCode = 403;
          break;
        default:
          errorMessage = `Errore Firebase Auth: ${error.message}`;
          statusCode = 500;
      }
    } else {
      errorMessage = error.message;
      statusCode = 400;
    }

    res.status(statusCode).json({ error: errorMessage });
  }
});