.PHONY: build restart lint fmt fmt-check

lint:
	@swiftlint lint

fmt:
	@swiftformat .

fmt-check:
	@swiftformat --lint .

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
	@APP="$(CURDIR)/build/Debug/happymode.app"; \
	if pgrep -x happymode >/dev/null; then \
		pkill -x happymode || true; \
		for i in 1 2 3 4 5 6 7 8 9 10; do \
			pgrep -x happymode >/dev/null || break; \
			sleep 0.1; \
		done; \
	fi; \
	if ! open "$$APP" >/dev/null 2>/tmp/happymode.open.log; then \
		echo "open failed, launching binary directly..."; \
		nohup "$$APP/Contents/MacOS/happymode" >/tmp/happymode.run.log 2>&1 </dev/null & \
	fi
