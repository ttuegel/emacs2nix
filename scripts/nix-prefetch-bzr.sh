#! /bin/sh -e

url=$1
repoName=$2
rev=$3
expHash=$4

hashType=$NIX_HASH_ALGO
if test -z "$hashType"; then
    hashType=sha256
fi
if test -z "$hashFormat"; then
    hashFormat=--base32
fi

if test -z "$url"; then
    echo "syntax: nix-prefetch-bzr URL REPO-NAME [REVISION [EXPECTED-HASH]]" >&2
    exit 1
fi

revarg="-r $rev"
test -n "$rev" || revarg=""

dstFile=$repoName-r$rev
test -n "$rev" || dstFile=$repoName

# If the hash was given, a file with that hash may already be in the
# store.
if test -n "$expHash"; then
    finalPath=$(nix-store --print-fixed-path --recursive "$hashType" "$expHash" $dstFile)
    if ! nix-store --check-validity "$finalPath" 2> /dev/null; then
        finalPath=
    fi
    hash=$expHash
fi


# If we don't know the hash or a path with that hash doesn't exist,
# download the file and add it to the store.
if test -z "$finalPath"; then
    tmpPath="$(mktemp -d "${TMPDIR:-/tmp}/bzr-checkout-tmp-XXXXXXXX")"
    trap "rm -rf \"$tmpPath\"" EXIT

    tmpFile="$tmpPath/$dstFile"

    # Perform the checkout.
    bzr -Ossl.cert_reqs=none export $revarg --format=dir "$tmpFile" "$url"

    echo "bzr revision is $(bzr revno $revarg "$url")" >&2

    # Compute the hash.
    hash=$(nix-hash --type $hashType $hashFormat $tmpFile)
    if ! test -n "$QUIET"; then echo "hash is $hash" >&2; fi

    # Add the downloaded file to the Nix store.
    finalPath=$(nix-store --add-fixed --recursive "$hashType" $tmpFile)

    if test -n "$expHash" -a "$expHash" != "$hash"; then
        echo "hash mismatch for URL \`$url'"
        exit 1
    fi
fi

if ! test -n "$QUIET"; then echo "path is $finalPath" >&2; fi

echo $hash

if test -n "$PRINT_PATH"; then
    echo $finalPath
fi
