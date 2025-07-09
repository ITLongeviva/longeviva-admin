// createAdmin.js
const admin = require('firebase-admin');
const readline = require('readline');

// Importa la service account key
const serviceAccount = require('./serviceAccountKey.json');

// Inizializza Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'longeviva-app'
});

const auth = admin.auth();
const db = admin.firestore();

// Funzione per creare input interattivo
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

// Funzione principale per creare admin
async function createAdmin() {
  console.log('🚀 Creazione Admin per Longeviva\n');

  try {
    // Raccolta dati interattiva
    const name = await question('Nome completo dell\'admin: ');
    const email = await question('Email: ');
    const password = await question('Password (min 8 caratteri): ');

    // Validazione base
    if (!name || !email || !password) {
      throw new Error('Tutti i campi sono obbligatori');
    }

    if (password.length < 8) {
      throw new Error('La password deve essere almeno 8 caratteri');
    }

    if (!email.includes('@')) {
      throw new Error('Email non valida');
    }

    console.log('\n⏳ Creazione admin in corso...\n');

    // 1. Crea utente in Firebase Auth
    console.log('1️⃣ Creazione utente in Firebase Auth...');
    const userRecord = await auth.createUser({
      email: email.trim(),
      password: password,
      displayName: name.trim(),
      emailVerified: true
    });

    console.log('   ✅ Utente creato con UID:', userRecord.uid);

    // 2. Imposta custom claims
    console.log('\n2️⃣ Impostazione permessi admin...');
    await auth.setCustomUserClaims(userRecord.uid, {
      admin: true,
      role: 'ADMIN'
    });

    console.log('   ✅ Permessi admin assegnati');

    // 3. Crea profilo in admin_profiles
    console.log('\n3️⃣ Creazione profilo in admin_profiles...');
    await db.collection('admin_profiles').doc(userRecord.uid).set({
      name: name.trim(),
      email: email.trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      role: 'ADMIN'
    });

    console.log('   ✅ Profilo creato in admin_profiles');

    // 4. Crea documento in admins collection per compatibilità
    console.log('\n4️⃣ Creazione documento in admins collection...');
    await db.collection('admins').doc(userRecord.uid).set({
      id: userRecord.uid,
      name: name.trim(),
      email: email.trim(),
      password: '', // Non salviamo la password in chiaro
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('   ✅ Documento creato in admins collection');

    // 5. Verifica che tutto sia andato a buon fine
    console.log('\n5️⃣ Verifica creazione...');

    // Verifica auth
    const verifyUser = await auth.getUser(userRecord.uid);
    const claims = verifyUser.customClaims || {};

    // Verifica Firestore
    const adminProfile = await db.collection('admin_profiles').doc(userRecord.uid).get();
    const adminDoc = await db.collection('admins').doc(userRecord.uid).get();

    if (claims.admin && adminProfile.exists && adminDoc.exists) {
      console.log('   ✅ Verifica completata con successo!');

      // Riepilogo finale
      console.log('\n' + '='.repeat(50));
      console.log('🎉 ADMIN CREATO CON SUCCESSO!');
      console.log('='.repeat(50));
      console.log('\n📋 Riepilogo:');
      console.log(`   Nome: ${name}`);
      console.log(`   Email: ${email}`);
      console.log(`   Password: ${password}`);
      console.log(`   UID: ${userRecord.uid}`);
      console.log('\n✨ Ora puoi accedere all\'app Longeviva Admin con queste credenziali!');
      console.log('='.repeat(50) + '\n');
    } else {
      console.log('   ⚠️  Attenzione: Verifica parzialmente fallita');
      console.log('   Admin claims:', claims.admin ? '✅' : '❌');
      console.log('   Admin profile:', adminProfile.exists ? '✅' : '❌');
      console.log('   Admin doc:', adminDoc.exists ? '✅' : '❌');
    }

  } catch (error) {
    console.error('\n❌ Errore durante la creazione admin:');

    if (error.code === 'auth/email-already-exists') {
      console.error('   L\'email specificata è già registrata nel sistema.');
      console.error('   Usa un\'email diversa o elimina l\'utente esistente.');
    } else if (error.code === 'auth/invalid-email') {
      console.error('   L\'email specificata non è valida.');
    } else if (error.code === 'auth/weak-password') {
      console.error('   La password è troppo debole.');
    } else {
      console.error('  ', error.message);
    }

    console.error('\n💡 Suggerimento: Controlla i log sopra per maggiori dettagli.\n');
  } finally {
    rl.close();
    process.exit();
  }
}

// Versione non interattiva (con parametri da command line)
async function createAdminWithArgs(name, email, password) {
  try {
    console.log('🚀 Creazione Admin per Longeviva (modalità diretta)\n');

    // Validazione
    if (!name || !email || !password) {
      throw new Error('Uso: node createAdmin.js "Nome Cognome" "email@example.com" "password"');
    }

    if (password.length < 8) {
      throw new Error('La password deve essere almeno 8 caratteri');
    }

    console.log(`📝 Creazione admin per: ${name} (${email})\n`);

    // Segui gli stessi passaggi della versione interattiva
    const userRecord = await auth.createUser({
      email: email.trim(),
      password: password,
      displayName: name.trim(),
      emailVerified: true
    });

    await auth.setCustomUserClaims(userRecord.uid, {
      admin: true,
      role: 'ADMIN'
    });

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
      password: '',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await batch.commit();

    console.log('\n✅ Admin creato con successo!');
    console.log(`   UID: ${userRecord.uid}`);
    console.log(`   Email: ${email}`);
    console.log(`   Password: ${password}\n`);

  } catch (error) {
    console.error('\n❌ Errore:', error.message);
  } finally {
    process.exit();
  }
}

// Script principale
async function main() {
  // Controlla se sono stati passati argomenti da command line
  const args = process.argv.slice(2);

  if (args.length === 3) {
    // Modalità con parametri: node createAdmin.js "Nome" "email" "password"
    await createAdminWithArgs(args[0], args[1], args[2]);
  } else if (args.length > 0 && args.length < 3) {
    console.error('❌ Parametri insufficienti!');
    console.error('Uso: node createAdmin.js "Nome Cognome" "email@example.com" "password"');
    console.error('Oppure: node createAdmin.js (per modalità interattiva)');
    process.exit(1);
  } else {
    // Modalità interattiva
    await createAdmin();
  }
}

// Avvia lo script
main().catch(error => {
  console.error('Errore fatale:', error);
  process.exit(1);
});