# Aufgaben rund ums Add-on. Pfade stehen in config.mk (Vorlage: config.mk.example).
-include config.mk

ADDON   := AutoGroupFinder
VERSION := $(shell sed -n 's/^\#\# Version: *//p' $(ADDON)/$(ADDON).toc)

.PHONY: test deploy install zip pdf release

test:
	@scripts/test.sh

# Tests, dann auf den Spielrechner; der Zielordner wird vorher geleert (keine Altdateien)
deploy: test
	ssh -o BatchMode=yes $(REMOTE_HOST) "rm -rf '$(REMOTE_ADDONS)/$(ADDON)' && mkdir -p '$(REMOTE_ADDONS)/$(ADDON)'"
	scp -q -r $(ADDON)/* "$(REMOTE_HOST):$(REMOTE_ADDONS)/$(ADDON)/"
	@echo "Auf $(REMOTE_HOST) installiert. /reload reicht; nur ein neuer Add-on-Ordner braucht einen Neustart von WoW."

# Tests, dann in den lokalen WoW-Ordner
install: test
	rm -rf "$(LOCAL_ADDONS)/$(ADDON)"
	cp -R $(ADDON) "$(LOCAL_ADDONS)/$(ADDON)"
	@echo "Lokal installiert: $(LOCAL_ADDONS)/$(ADDON)"

# Paket für CurseForge: der Ordner AutoGroupFinder/ ganz oben im Zip
zip: test
	@mkdir -p dist
	rm -f dist/$(ADDON)-$(VERSION).zip
	zip -qr dist/$(ADDON)-$(VERSION).zip $(ADDON) -x '*.DS_Store'
	@echo "dist/$(ADDON)-$(VERSION).zip"

pdf:
	@scripts/checklist-pdf.sh

# Neue Version: .toc hochsetzen, testen, Tag pushen; GitHub Actions baut und lädt zu CurseForge hoch.
# make release  (letzte Stelle +1)  ·  make release V=0.7.0  ·  make release DRY=1
release:
	@DRY=$(DRY) scripts/release.sh $(V)
