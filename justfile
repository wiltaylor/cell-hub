# Cell Hub and Cell Launcher — the server and the desktop library for .cell games.

[default, private]
main:
	@just --list

# Install the JavaScript workspace
[group('build')]
js-install:
	pnpm install

# Build the hub web UI (apps/hub-web/dist, embedded into cell-hub)
[group('hub')]
hub-web-build: js-install
	pnpm --dir apps/hub-web build

# Build the cell-hub server with the embedded web UI
[group('hub')]
hub-build: hub-web-build
	cargo build --release -p cell-hub

# Run a hub on port 8787 with ./hub-data (the first admin invite code is printed)
[group('hub')]
hub-serve: hub-build
	./target/release/cell-hub serve --listen 0.0.0.0:8787 --data ./hub-data

# Open the terminal console against a hub (signs in with your profile)
[group('hub')]
hub-console url='http://127.0.0.1:8787':
	./target/release/cell-hub console --url {{url}}

# Fetch the Cell builder from the cell repository's releases
[group('build')]
cell-builder version='0.3.0':
	@test -x tools/cell-builder.cell || (gh release download v{{version}} -R wiltaylor/cell -p 'cell-builder-*.cell' -O tools/cell-builder.cell && chmod +x tools/cell-builder.cell)

# Build the hub as a static binary
[group('hub')]
hub-static-build: hub-web-build
	cargo build --release -p cell-hub --target x86_64-unknown-linux-musl

# Package the hub as a cell: dist/cell-hub.cell
[group('hub')]
hub-cell: hub-static-build cell-builder
	mkdir -p dist
	cd packaging && ../tools/cell-builder.cell build cell-hub.wcl -o ../dist/cell-hub.cell

# Run the packaged hub (data in the cell's private home)
[group('hub')]
hub-cell-run *args:
	./dist/cell-hub.cell {{args}}

# Package the launcher as a cell: dist/cell-launcher.cell
[group('launcher')]
launcher-cell: launcher-build cell-builder
	mkdir -p dist
	cd packaging && ../tools/cell-builder.cell build cell-launcher.wcl -o ../dist/cell-launcher.cell

# Build the desktop launcher through the Tauri CLI (a plain cargo build loads the dev URL)
[group('launcher')]
launcher-build: js-install
	pnpm --dir apps/launcher tauri build --no-bundle

# Run the desktop launcher (builds it first only when the binary is missing)
[group('launcher')]
launcher:
	@test -x target/release/cell-launcher-app || just launcher-build
	./target/release/cell-launcher-app

# Run the launcher with hot reload (Vite + Tauri dev)
[group('launcher')]
launcher-dev: js-install
	pnpm --dir apps/launcher tauri dev

# Install the launcher for this user: ~/.local/bin and an app-menu entry
[group('launcher')]
launcher-install:
	@test -x target/release/cell-launcher-app || just launcher-build
	mkdir -p ~/.local/bin ~/.local/share/applications ~/.local/share/icons/hicolor/128x128/apps
	cp target/release/cell-launcher-app ~/.local/bin/cell-launcher-app
	cp apps/launcher/src-tauri/icons/128x128.png ~/.local/share/icons/hicolor/128x128/apps/cell-launcher.png
	printf '[Desktop Entry]\nType=Application\nName=Cell Launcher\nComment=Your library of portable games\nExec=%s/.local/bin/cell-launcher-app\nIcon=cell-launcher\nTerminal=false\nCategories=Game;\n' "$HOME" > ~/.local/share/applications/cell-launcher.desktop
	-update-desktop-database ~/.local/share/applications 2>/dev/null
	@echo "installed: run 'cell-launcher-app' or find Cell Launcher in the app menu"

# Format, lint and test everything
[group('check')]
workspace-check: js-install
	pnpm --dir apps/hub-web check
	pnpm --dir apps/launcher check
	cargo fmt --all --check
	cargo clippy --workspace --all-targets -- -D warnings
	cargo test --workspace
