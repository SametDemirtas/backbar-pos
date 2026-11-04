FLUTTER ?= flutter
TESTS = packages/core/test apps/pos/test apps/manager/test
EMULATOR_DEFINE = --dart-define=USE_FIREBASE_EMULATOR=true

.PHONY: help setup test analyze rules seed emulator pos manager check clean

help:
	@echo "setup     resolve Dart and Node dependencies"
	@echo "check     analyze + Dart tests + rules tests (everything)"
	@echo "test      Dart tests across all three packages"
	@echo "analyze   static analysis across the workspace"
	@echo "rules     security rules tests, against the emulator"
	@echo "emulator  start Firestore and Auth locally"
	@echo "seed      write the demo venue menu into the running emulator"
	@echo "pos       run the till in Chrome, against the emulator"
	@echo "manager   run the manager app in Chrome, against the emulator"
	@echo "clean     remove build output"

setup:
	$(FLUTTER) pub get
	npm --prefix tools ci

test:
	$(FLUTTER) test $(TESTS)

analyze:
	$(FLUTTER) analyze

rules:
	npm --prefix tools test

check: analyze test rules

emulator:
	firebase emulators:start

seed:
	npm --prefix tools run seed

pos:
	cd apps/pos && $(FLUTTER) run -d chrome $(EMULATOR_DEFINE)

manager:
	cd apps/manager && $(FLUTTER) run -d chrome $(EMULATOR_DEFINE)

clean:
	$(FLUTTER) clean
	rm -rf apps/pos/build apps/manager/build packages/core/build
