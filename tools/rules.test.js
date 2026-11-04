import assert from 'node:assert/strict'
import { after, before, beforeEach, describe, it } from 'node:test'
import { readFileSync } from 'node:fs'

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing'
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore'

const VENUE = 'copper-kettle'
const ITEM = `venues/${VENUE}/menuItems/guinness`

let testEnv

function till(uid = 'till-uid') {
  return testEnv.authenticatedContext(uid).firestore()
}

function stranger() {
  return testEnv.unauthenticatedContext().firestore()
}

const validItem = (overrides = {}) => ({
  name: 'Guinness, pint',
  priceCents: 720,
  category: 'drinks',
  isAvailable: true,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
})

const validOrder = (uid = 'till-uid', overrides = {}) => ({
  lines: [
    {
      itemId: 'guinness',
      name: 'Guinness, pint',
      unitPriceCents: 720,
      quantity: 3,
      amountCents: 2160,
    },
  ],
  itemCount: 3,
  totalCents: 2160,
  tillLabel: 'TILL 2',
  staffUid: uid,
  createdAt: serverTimestamp(),
  ...overrides,
})

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-backbar-pos',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  })
})

after(async () => {
  await testEnv?.cleanup()
})

beforeEach(async () => {
  await testEnv.clearFirestore()
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), ITEM), {
      name: 'Guinness, pint',
      priceCents: 720,
      category: 'drinks',
      isAvailable: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    })
  })
})

describe('menu items — who gets in', () => {
  it('a device that has not signed in cannot read the menu', async () => {
    await assertFails(getDoc(doc(stranger(), ITEM)))
  })

  it('a device that has not signed in cannot write the menu', async () => {
    await assertFails(
      setDoc(doc(stranger(), `venues/${VENUE}/menuItems/new`), validItem()),
    )
  })

  it('a signed-in device can read the menu', async () => {
    await assertSucceeds(getDoc(doc(till(), ITEM)))
  })

  it('a signed-in device can create a valid item', async () => {
    await assertSucceeds(
      setDoc(doc(till(), `venues/${VENUE}/menuItems/neck-oil`), validItem()),
    )
  })
})

describe('menu items — the document has to make sense', () => {
  const rejects = (label, overrides) => {
    it(label, async () => {
      await assertFails(
        setDoc(
          doc(till(), `venues/${VENUE}/menuItems/attempt`),
          validItem(overrides),
        ),
      )
    })
  }

  rejects('no name', { name: '' })
  rejects('a name longer than the till can render', { name: 'x'.repeat(61) })
  rejects('a name that is not a string', { name: 42 })

  rejects('a free drink', { priceCents: 0 })
  rejects('a price that pays the customer', { priceCents: -500 })
  rejects('a price as a float', { priceCents: 7.2 })
  rejects('a price as a string', { priceCents: '720' })
  rejects('a price past the agreed ceiling', { priceCents: 100000001 })

  rejects('a category this build has never heard of', { category: 'apparel' })
  rejects('a category that is not a string', { category: 3 })

  rejects('availability as a string', { isAvailable: 'true' })
  rejects('a field nobody declared', { colour: 'black' })
  rejects('a client-chosen createdAt', { createdAt: new Date(2020, 1, 1) })
  rejects('a client-chosen updatedAt', { updatedAt: new Date(2020, 1, 1) })

  it('accepts the largest price the ceiling allows', async () => {
    await assertSucceeds(
      setDoc(
        doc(till(), `venues/${VENUE}/menuItems/vip-table`),
        validItem({ priceCents: 100000000 }),
      ),
    )
  })
})

describe('menu items — updating', () => {
  it('a signed-in device can mark an item sold out', async () => {
    await assertSucceeds(
      updateDoc(doc(till(), ITEM), {
        isAvailable: false,
        updatedAt: serverTimestamp(),
      }),
    )
  })

  it('an update without a fresh updatedAt is refused', async () => {
    await assertFails(
      updateDoc(doc(till(), ITEM), { isAvailable: false }),
    )
  })

  it('an update cannot rewrite when the item was created', async () => {
    await assertFails(
      updateDoc(doc(till(), ITEM), {
        isAvailable: false,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    )
  })

  describe('an item created in the console, with no createdAt', () => {
    const CONSOLE_ITEM = `venues/${VENUE}/menuItems/console-item`

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), CONSOLE_ITEM), {
          name: 'Olives',
          priceCents: 450,
          category: 'snacks',
          isAvailable: true,
        })
      })
    })

    it('can still be edited', async () => {
      await assertSucceeds(
        updateDoc(doc(till(), CONSOLE_ITEM), {
          priceCents: 500,
          updatedAt: serverTimestamp(),
        }),
      )
    })

    it('cannot be given a null createdAt either', async () => {
      await assertFails(
        updateDoc(doc(till(), CONSOLE_ITEM), {
          priceCents: 500,
          createdAt: null,
          updatedAt: serverTimestamp(),
        }),
      )
    })

    it('cannot be given a createdAt after the fact', async () => {
      await assertFails(
        updateDoc(doc(till(), CONSOLE_ITEM), {
          priceCents: 500,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      )
    })
  })

  describe('an item holding a price these rules would refuse', () => {
    const LEGACY_ITEM = `venues/${VENUE}/menuItems/legacy-item`

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), LEGACY_ITEM), {
          name: 'Coke, bottle',
          priceCents: 3.5,
          category: 'drinks',
          isAvailable: false,
          createdAt: new Date(),
          updatedAt: new Date(),
        })
      })
    })

    it('can still be renamed, leaving the price alone', async () => {
      await assertSucceeds(
        updateDoc(doc(till(), LEGACY_ITEM), {
          name: 'Coca-Cola, bottle',
          updatedAt: serverTimestamp(),
        }),
      )
    })

    it('can be given a valid price', async () => {
      await assertSucceeds(
        updateDoc(doc(till(), LEGACY_ITEM), {
          priceCents: 350,
          updatedAt: serverTimestamp(),
        }),
      )
    })

    it('cannot be given another invalid one', async () => {
      await assertFails(
        updateDoc(doc(till(), LEGACY_ITEM), {
          priceCents: 3.6,
          updatedAt: serverTimestamp(),
        }),
      )
    })
  })

  it('an update cannot smuggle in an invalid price', async () => {
    await assertFails(
      updateDoc(doc(till(), ITEM), {
        priceCents: 0,
        updatedAt: serverTimestamp(),
      }),
    )
  })

  it('a signed-in device can delete an item', async () => {
    await assertSucceeds(deleteDoc(doc(till(), ITEM)))
  })

  it('a stranger cannot delete an item', async () => {
    await assertFails(deleteDoc(doc(stranger(), ITEM)))
  })
})

describe('orders', () => {
  const path = 'order-1'
  const orderRef = (db) => doc(db, `venues/${VENUE}/orders/${path}`)

  it('a till can submit a check', async () => {
    await assertSucceeds(setDoc(orderRef(till()), validOrder()))
  })

  it('a stranger cannot submit a check', async () => {
    await assertFails(setDoc(orderRef(stranger()), validOrder('till-uid')))
  })

  it('a device cannot attribute takings to somebody else', async () => {
    await assertFails(
      setDoc(orderRef(till('till-uid')), validOrder('someone-else')),
    )
  })

  it('an empty check is refused', async () => {
    await assertFails(
      setDoc(orderRef(till()), validOrder('till-uid', { lines: [] })),
    )
  })

  it('a check with a zero total is refused', async () => {
    await assertFails(
      setDoc(orderRef(till()), validOrder('till-uid', { totalCents: 0 })),
    )
  })

  it('a check large enough to be an attack is refused', async () => {
    const lines = Array.from({ length: 201 }, () => ({
      itemId: 'x',
      name: 'x',
      unitPriceCents: 1,
      quantity: 1,
      amountCents: 1,
    }))
    await assertFails(
      setDoc(orderRef(till()), validOrder('till-uid', { lines })),
    )
  })

  it('a check with a total no till could ring in is refused', async () => {
    await assertFails(
      setDoc(
        orderRef(till()),
        validOrder('till-uid', { totalCents: 100000001 }),
      ),
    )
  })

  it('a check with an absurd item count is refused', async () => {
    await assertFails(
      setDoc(orderRef(till()), validOrder('till-uid', { itemCount: 10001 })),
    )
  })

  it('a check from a till with no label is refused', async () => {
    await assertFails(
      setDoc(orderRef(till()), validOrder('till-uid', { tillLabel: '' })),
    )
  })

  it('a check with a field nobody declared is refused', async () => {
    await assertFails(
      setDoc(orderRef(till()), validOrder('till-uid', { discount: 100 })),
    )
  })

  it('a check cannot be written twice under the same id', async () => {
    await assertSucceeds(setDoc(orderRef(till()), validOrder()))
    await assertFails(setDoc(orderRef(till()), validOrder()))
    await assertSucceeds(getDoc(orderRef(till())))
  })

  it('a submitted check cannot be edited', async () => {
    await assertSucceeds(setDoc(orderRef(till()), validOrder()))
    await assertFails(updateDoc(orderRef(till()), { totalCents: 1 }))
  })

  it('a submitted check cannot be deleted', async () => {
    await assertSucceeds(setDoc(orderRef(till()), validOrder()))
    await assertFails(deleteDoc(orderRef(till())))
  })

  it('a till can read back what it sent', async () => {
    await assertSucceeds(setDoc(orderRef(till()), validOrder()))
    await assertSucceeds(getDoc(orderRef(till())))
  })

  it('a till cannot read another device\'s takings', async () => {
    await assertSucceeds(setDoc(orderRef(till('till-a')), validOrder('till-a')))
    await assertFails(getDoc(orderRef(till('till-b'))))
  })
})

describe('one venue cannot touch another', () => {
  const OTHER = 'venues/somebody-elses-bar/menuItems/guinness'
  const INVENTED = 'venues/not-a-venue-at-all/menuItems/x'

  it('cannot read another venue\'s menu', async () => {
    await assertFails(getDoc(doc(till(), OTHER)))
  })

  it('cannot create an item in another venue', async () => {
    await assertFails(setDoc(doc(till(), OTHER), validItem()))
  })

  it('cannot re-price another venue\'s drink', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), OTHER), {
        name: 'Guinness, pint',
        priceCents: 720,
        category: 'drinks',
        isAvailable: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      })
    })

    await assertFails(
      updateDoc(doc(till(), OTHER), {
        priceCents: 1,
        updatedAt: serverTimestamp(),
      }),
    )
  })

  it('cannot delete another venue\'s drink', async () => {
    await assertFails(deleteDoc(doc(till(), OTHER)))
  })

  it('cannot post orders into another venue\'s takings', async () => {
    await assertFails(
      setDoc(
        doc(till(), 'venues/somebody-elses-bar/orders/order-1'),
        validOrder(),
      ),
    )
  })

  it('cannot invent a venue', async () => {
    await assertFails(setDoc(doc(till(), INVENTED), validItem()))
    await assertFails(getDoc(doc(till(), INVENTED)))
  })
})

describe('the sold-out toggle is never the blocked action', () => {
  const legacy = async (overrides) => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), ITEM), {
        name: 'Guinness, pint',
        priceCents: 720,
        category: 'drinks',
        isAvailable: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        ...overrides,
      })
    })
  }

  const toggles = (label, overrides) => {
    it(label, async () => {
      await legacy(overrides)
      await assertSucceeds(
        updateDoc(doc(till(), ITEM), {
          isAvailable: false,
          updatedAt: serverTimestamp(),
        }),
      )
    })
  }

  toggles('on an item filed under a retired category', { category: 'apparel' })
  toggles('on an item whose name predates the length cap', {
    name: 'x'.repeat(80),
  })
  toggles('on an item with a legacy zero price', { priceCents: 0 })

  it('but the toggle cannot smuggle a bad value through', async () => {
    await legacy({})
    await assertFails(
      updateDoc(doc(till(), ITEM), {
        isAvailable: false,
        priceCents: 0,
        updatedAt: serverTimestamp(),
      }),
    )
  })

  it('a price change alongside the flag is a normal edit, and allowed',
      async () => {
    await legacy({})
    await assertSucceeds(
      updateDoc(doc(till(), ITEM), {
        isAvailable: false,
        priceCents: 750,
        updatedAt: serverTimestamp(),
      }),
    )
  })

  it('and a real edit is still validated in full', async () => {
    await legacy({})
    await assertFails(
      updateDoc(doc(till(), ITEM), {
        name: '',
        updatedAt: serverTimestamp(),
      }),
    )
  })
})

describe('an edit leaves what it did not touch alone', () => {
  const stored = async (overrides) => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), ITEM), {
        name: 'Tote bag',
        priceCents: 1500,
        category: 'merch',
        isAvailable: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        ...overrides,
      })
    })
  }

  const edit = (fields) =>
    updateDoc(doc(till(), ITEM), { ...fields, updatedAt: serverTimestamp() })

  it('re-prices an item under a retired category, keeping the category',
      async () => {
    await stored({ category: 'apparel' })
    await assertSucceeds(edit({ priceCents: 1600 }))
  })

  it('but cannot move it to another category nobody knows', async () => {
    await stored({ category: 'apparel' })
    await assertFails(edit({ category: 'hats' }))
  })

  it('and can move it to a known one', async () => {
    await stored({ category: 'apparel' })
    await assertSucceeds(edit({ category: 'merch' }))
  })

  it('edits an item holding a field nobody declared', async () => {
    await stored({ colour: 'black' })
    await assertSucceeds(edit({ name: 'Tote bag, black' }))
  })

  it('but cannot change that field', async () => {
    await stored({ colour: 'black' })
    await assertFails(edit({ colour: 'red' }))
  })

  it('nor add one', async () => {
    await stored({})
    await assertFails(edit({ colour: 'red' }))
  })
})

describe('everything else is closed', () => {
  it('the venue document itself is not writable', async () => {
    await assertFails(
      setDoc(doc(till(), `venues/${VENUE}`), { displayName: 'Mine now' }),
    )
  })

  it('an invented collection is not writable', async () => {
    await assertFails(setDoc(doc(till(), 'staff/till-uid'), { role: 'manager' }))
  })

  it('an invented collection is not readable', async () => {
    await assertFails(getDoc(doc(till(), 'secrets/keys')))
  })
})

describe('the rules file and the Dart layer agree', () => {
  it('names the same four categories the enum does', () => {
    const rules = readFileSync('../firestore.rules', 'utf8')
    const dart = readFileSync(
      '../packages/core/lib/src/models/menu_category.dart',
      'utf8',
    )
    const inRules = rules
      .match(/value in \[([^\]]+)\]/)[1]
      .match(/'([a-z]+)'/g)
      .map((s) => s.replaceAll("'", ''))
    const inDart = [...dart.matchAll(/^\s{2}\w+\('([a-z]+)',/gm)].map(
      (m) => m[1],
    )

    assert.deepEqual(inRules.sort(), inDart.sort())
  })

  it('enforces the same price ceiling Money does', () => {
    const rules = readFileSync('../firestore.rules', 'utf8')
    const dart = readFileSync(
      '../packages/core/lib/src/money/money.dart',
      'utf8',
    )
    const inRules = rules.match(/priceCents <= (\d+)/)[1]
    const inDart = dart.match(/maxCents = (\d+)/)[1]

    assert.equal(inRules, inDart)
  })

  it('caps an order the way Order does', () => {
    const rules = readFileSync('../firestore.rules', 'utf8')
    const order = readFileSync(
      '../packages/core/lib/src/models/order.dart',
      'utf8',
    )
    const money = readFileSync(
      '../packages/core/lib/src/money/money.dart',
      'utf8',
    )

    assert.equal(
      rules.match(/data\.lines\.size\(\) <= (\d+)/)[1],
      order.match(/maxLines = (\d+)/)[1],
    )
    assert.equal(
      rules.match(/itemCount <= (\d+)/)[1],
      order.match(/maxItems = (\d+)/)[1],
    )
    assert.equal(
      rules.match(/totalCents <= (\d+)/)[1],
      money.match(/maxCents = (\d+)/)[1],
    )
  })

  it('enforces the same name length MenuItemDraft does', () => {
    const rules = readFileSync('../firestore.rules', 'utf8')
    const dart = readFileSync(
      '../packages/core/lib/src/models/menu_item.dart',
      'utf8',
    )
    const inRules = rules.match(/name\.size\(\) <= (\d+)/)[1]
    const inDart = dart.match(/maxNameLength = (\d+)/)[1]

    assert.equal(inRules, inDart)
  })

  it('caps a till label the way VenueConfig does', () => {
    const rules = readFileSync('../firestore.rules', 'utf8')
    const dart = readFileSync(
      '../packages/core/lib/src/app/venue.dart',
      'utf8',
    )
    const inRules = rules.match(/tillLabel\.size\(\) <= (\d+)/)[1]
    const inDart = dart.match(/tillLabel\.length <= (\d+)/)[1]

    assert.equal(inRules, inDart)
  })
})
