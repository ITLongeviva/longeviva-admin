// deleteAdmin.js
const admin = require('firebase-admin');
const readline = require('readline');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'longeviva-app'
});

const auth = admin.auth();
const db = admin.firestore();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

async function deleteAdmin() {
  const email = await new Promise(resolve =>
    rl.question('Email dell\'admin da eliminare: ', resolve)
  );

  try {
    // Trova l'utente
    const user = await auth.getUserByEmail(email);

    console.log(`\n⚠️  Stai per eliminare:`);
    console.log(`   Nome: ${user.displayName}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   UID: ${user.uid}`);

    const confirm = await new Promise(resolve =>
      rl.question('\nSei sicuro? (yes/no): ', resolve)
    );

    if (confirm.toLowerCase() === 'yes') {
      // Elimina da Auth
      await auth.deleteUser(user.uid);

      // Elimina da Firestore
      const batch = db.batch();
      batch.delete(db.collection('admin_profiles').doc(user.uid));
      batch.delete(db.collection('admins').doc(user.uid));
      await batch.commit();

      console.log('\n✅ Admin eliminato con successo!');
    } else {
      console.log('\n❌ Operazione annullata.');
    }

  } catch (error) {
    console.error('\n❌ Errore:', error.message);
  }

  rl.close();
  process.exit();
}

deleteAdmin();