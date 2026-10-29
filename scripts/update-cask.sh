#!/usr/bin/env bash
# GitHub Releases に公開した DMG に合わせて、Homebrew tap (ssakihara/homebrew-tap) の
# Casks/snapdock.rb を書き換えてプッシュする。
#
# 使い方:
#   scripts/update-cask.sh <バージョン>      例: scripts/update-cask.sh 0.2.0
# 任意の環境変数:
#   TAP_DIR    tap リポジトリのローカルクローン。未設定なら一時ディレクトリにクローンする
#   NO_PUSH=1  コミットまでにしてプッシュしない
set -euo pipefail

VERSION="${1:?バージョンを指定してください（例: 0.2.0）}"
VERSION="${VERSION#v}"

TAP_REPO="ssakihara/homebrew-tap"
DMG_URL="https://github.com/ssakihara/snapdock/releases/download/v$VERSION/SnapDock-$VERSION.dmg"

echo "==> sha256 を計算: $DMG_URL"
SHA256=$(curl -fsSL "$DMG_URL" | shasum -a 256 | awk '{print $1}')

if [[ -z "${TAP_DIR:-}" ]]; then
  TAP_DIR=$(mktemp -d)
  trap 'rm -rf "$TAP_DIR"' EXIT
  git clone --quiet "https://github.com/$TAP_REPO.git" "$TAP_DIR"
fi

mkdir -p "$TAP_DIR/Casks"
cat > "$TAP_DIR/Casks/snapdock.rb" <<RUBY
cask "snapdock" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/ssakihara/snapdock/releases/download/v#{version}/SnapDock-#{version}.dmg"
  name "SnapDock"
  desc "Menu bar app to drag and drop your latest screenshots"
  homepage "https://github.com/ssakihara/snapdock"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "SnapDock.app"

  uninstall quit: "com.ssakihara.SnapDock"

  zap trash: "~/Library/Preferences/com.ssakihara.SnapDock.plist"
end
RUBY

cd "$TAP_DIR"
if git diff --quiet -- Casks/snapdock.rb && git ls-files --error-unmatch Casks/snapdock.rb >/dev/null 2>&1; then
  echo "==> Cask はすでに $VERSION です"
  exit 0
fi

git add Casks/snapdock.rb
git commit --quiet -m "snapdock $VERSION"
if [[ "${NO_PUSH:-}" == "1" ]]; then
  echo "==> コミットしました（プッシュなし）: $TAP_DIR"
else
  git push --quiet origin HEAD
  echo "==> $TAP_REPO を snapdock $VERSION に更新しました"
fi
