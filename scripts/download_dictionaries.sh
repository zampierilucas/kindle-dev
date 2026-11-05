#!/bin/bash
# KOReader Dictionary Downloader
# Downloads English dictionaries in StarDict format

set -e

DICT_DIR="${1:-./dictionaries}"
mkdir -p "$DICT_DIR"
cd "$DICT_DIR"

echo "=== Downloading KOReader Dictionaries ==="
echo "Target directory: $DICT_DIR"
echo ""

# 1. GCIDE (GNU Collaborative International Dictionary of English)
# Based on Webster's 1913 + WordNet + community additions
# 131,566+ headwords
echo "[1/6] Downloading GCIDE..."
curl -LO "http://build.koreader.rocks/download/dict/gcide.tar.gz"
tar -xzf gcide.tar.gz
rm gcide.tar.gz
echo "      Done: GCIDE"

# 2. CIA World Factbook (encyclopedic reference)
echo "[2/6] Downloading CIA World Factbook..."
curl -LO "http://build.koreader.rocks/download/dict/factbook.tar.gz"
tar -xzf factbook.tar.gz
rm factbook.tar.gz
echo "      Done: Factbook"

# 3. Etymology Dictionary (Douglas Harper's Online Etymology Dictionary)
echo "[3/6] Downloading Etymology Dictionary..."
curl -LO "http://tovotu.de/data/stardict/etymonline.zip"
unzip -q etymonline.zip
rm etymonline.zip
echo "      Done: Etymology"

# 4. Wiktionary English-English (updated monthly, very comprehensive)
echo "[4/6] Downloading Wiktionary English-English..."
curl -LO "https://github.com/xxyzz/wiktionary_stardict/releases/download/20251215/en-en.tar.zst"
tar --zstd -xf en-en.tar.zst
rm en-en.tar.zst
echo "      Done: Wiktionary"

# 5. Webster's 1913 (classic literary dictionary)
echo "[5/6] Downloading Webster's 1913..."
git clone --depth 1 https://github.com/ahacop/websters-dict-1913-stardict.git websters-1913-temp
mv websters-1913-temp/stardict-websters-1913 ./websters-1913
rm -rf websters-1913-temp
echo "      Done: Webster's 1913"

# 6. Alternative GCIDE from tovotu (backup/comparison)
echo "[6/6] Downloading GCIDE (tovotu version)..."
curl -LO "http://tovotu.de/data/stardict/gcide.zip"
unzip -q gcide.zip -d gcide-tovotu
rm gcide.zip
echo "      Done: GCIDE (tovotu)"

echo ""
echo "=== Download Complete ==="
echo ""
echo "Dictionaries downloaded:"
ls -la
echo ""
echo "To install on Kindle:"
echo "  1. Connect Kindle via USB"
echo "  2. Copy all folders to: koreader/data/dict/"
echo "  3. In KOReader: Menu > Search > Dictionary Settings > Enable dictionaries"
