import { initializeApp } from 'firebase/app'
import {
  collection,
  connectFirestoreEmulator,
  doc,
  getDocs,
  getFirestore,
  serverTimestamp,
  writeBatch,
} from 'firebase/firestore'
import {
  connectAuthEmulator,
  getAuth,
  signInAnonymously,
} from 'firebase/auth'

const PROJECT_ID = 'demo-backbar-pos'
const VENUE_ID = 'copper-kettle'

const MENU = [
  ['Guinness, pint', 720, 'drinks'],
  ['Camden Hells Lager, pint', 680, 'drinks'],
  ['Neck Oil IPA, pint', 650, 'drinks'],
  ['House Red, 175ml', 750, 'drinks'],
  ['Prosecco, 125ml', 600, 'drinks'],
  ['Espresso Martini', 1250, 'drinks'],
  ['Negroni', 1100, 'drinks'],
  ['Old Fashioned', 1150, 'drinks'],
  ['Aperol Spritz', 1000, 'drinks', false],
  ['Coke, bottle', 300, 'drinks'],
  ['Sparkling water, 330ml', 320, 'drinks'],
  ['Lime & soda', 220, 'drinks'],

  ['Loaded fries with smoked chilli mayo', 800, 'food'],
  ['Halloumi wrap', 950, 'food'],
  ['Beef burger', 1200, 'food'],
  ['Veggie burger', 1100, 'food', false],

  ['Salted crisps', 200, 'snacks'],
  ['Peanuts', 250, 'snacks'],
  ['Olives', 450, 'snacks'],

  ['Venue tote bag', 1500, 'merch'],
  ['Venue T-shirt', 2200, 'merch'],
]

async function main() {
  const app = initializeApp({
    apiKey: 'emulator-does-not-check-this',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: PROJECT_ID,
  })

  const db = getFirestore(app)
  connectFirestoreEmulator(db, '127.0.0.1', 8080)

  const auth = getAuth(app)
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true })
  await signInAnonymously(auth)

  const menu = collection(db, 'venues', VENUE_ID, 'menuItems')

  const existing = await getDocs(menu)
  if (existing.size > 0) {
    const clear = writeBatch(db)
    existing.forEach((snapshot) => clear.delete(snapshot.ref))
    await clear.commit()
    console.log(`Cleared ${existing.size} existing items.`)
  }

  const batch = writeBatch(db)
  for (const [name, priceCents, category, isAvailable = true] of MENU) {
    batch.set(doc(menu), {
      name,
      priceCents,
      category,
      isAvailable,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    })
  }
  await batch.commit()

  const soldOut = MENU.filter((item) => item[3] === false).length
  console.log(
    `Seeded ${MENU.length} items for ${VENUE_ID} ` +
      `(${soldOut} of them sold out, so the till has something to show).`,
  )
  process.exit(0)
}

main().catch((error) => {
  console.error(
    '\nSeeding failed. Is the emulator running?\n' +
      '  firebase emulators:start\n',
  )
  console.error(error)
  process.exit(1)
})
