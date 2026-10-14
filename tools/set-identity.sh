#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Replace the identity tokens (@OWNER@, @AUTHOR@, @AUTHOR_EMAIL@) in every
# tracked file with the values from identity.conf, and set the local git
# author. Run once, after filling in identity.conf. --dry-run lists files.
set -euo pipefail

cd "$(dirname "$0")/.."
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

# Parse KEY=VALUE lines (not sourced: values may contain spaces; optional
# surrounding quotes are removed).
OWNER="" AUTHOR="" AUTHOR_EMAIL=""
while IFS= read -r line; do
	case $line in ''|'#'*) continue ;; esac
	key=${line%%=*}; val=${line#*=}
	val=${val#\"}; val=${val%\"}; val=${val#\'}; val=${val%\'}
	case $key in
		OWNER) OWNER=$val ;;
		AUTHOR) AUTHOR=$val ;;
		AUTHOR_EMAIL) AUTHOR_EMAIL=$val ;;
	esac
done < identity.conf
for v in OWNER AUTHOR AUTHOR_EMAIL; do
	[ -n "${!v}" ] || { echo "identity.conf: $v is empty" >&2; exit 1; }
	case "${!v}" in *'|'*|*'&'*|*'\'*) echo "identity.conf: $v contains | & or \\" >&2; exit 1 ;; esac
done

mapfile -t files < <(git grep -l -I -E '@(OWNER|AUTHOR|AUTHOR_EMAIL)@' -- . \
	':!identity.conf' ':!tools/set-identity.sh' || true)
if [ ${#files[@]} -eq 0 ]; then
	echo "no tokens left"
else
	printf '%s\n' "${files[@]}"
	if [ $DRY -eq 0 ]; then
		sed -i -e "s|@OWNER@|$OWNER|g" -e "s|@AUTHOR_EMAIL@|$AUTHOR_EMAIL|g" \
			-e "s|@AUTHOR@|$AUTHOR|g" -- "${files[@]}"
		echo "replaced tokens in ${#files[@]} files"
	fi
fi
if [ $DRY -eq 0 ]; then
	git config user.name "$AUTHOR"
	git config user.email "$AUTHOR_EMAIL"
	echo "git author: $AUTHOR <$AUTHOR_EMAIL>"
fi
