.PHONY: build restart

build:
	@xcodebuild \
		-project happymode.xcodeproj \
		-scheme happymode \
		-configuration Debug \
		-sdk macosx \
		CODE_SIGNING_ALLOWED=NO \
		SYMROOT="$(CURDIR)/build" \
		clean build

restart: build
	@if pgrep -x happymode >/dev/null; then killall happymode; fi
	@open "$(CURDIR)/build/Debug/happymode.app"
