// listAdmins.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'longeviva-app'
});

const auth = admin.auth();
const db = admin.firestore();

async function listAdmins() {
  console.log('📋 Lista degli Admin esistenti:\n');

  try {
    // Ottieni tutti gli utenti
    const listUsersResult = await auth.listUsers();
    const adminUsers = [];

    // Filtra solo gli admin
    for (const user of listUsersResult.users) {
      const claims = user.customClaims || {};
      if (claims.admin) {
        adminUsers.push(user);
      }
    }

    if (adminUsers.length === 0) {
      console.log('❌ Nessun admin trovato nel sistema.');
      return;
    }

    console.log(`Trovati ${adminUsers.length} admin:\n`);

    for (const user of adminUsers) {
      console.log('-'.repeat(50));
      console.log(`Nome: ${user.displayName || 'N/A'}`);
      console.log(`Email: ${user.email}`);
      console.log(`UID: ${user.uid}`);
      console.log(`Email verificata: ${user.emailVerified ? '✅' : '❌'}`);
      console.log(`Account disabilitato: ${user.disabled ? '❌' : '✅ Attivo'}`);
      console.log(`Creato: ${new Date(user.metadata.creationTime).toLocaleString()}`);
      console.log(`Ultimo accesso: ${user.metadata.lastSignInTime ? new Date(user.metadata.lastSignInTime).toLocaleString() : 'Mai'}`);
    }

    console.log('-'.repeat(50));

  } catch (error) {
    console.error('❌ Errore:', error.message);
  }

  process.exit();
}

listAdmins();