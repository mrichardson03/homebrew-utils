require_relative "../Library/op_cli_requirement"

class OpAwsCredentialsClient < Formula
  desc "Password client script to fetch AWS credentials from 1Password"
  homepage "https://github.com/claui"
  url "file:///dev/null"
  version "1.1.0"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  depends_on "jq"
  depends_on OnePasswordCliRequirement

  def install
    (bin/"op-aws-credentials-client").write <<~EOS
      #!/bin/bash -eu
      \\set -o pipefail

      if \\[ "${SKIP_AWS_SECRET:-0}" -ne '0' ]; then
        \\printf '\\0'
        \\exit 0
      fi

      if \\[ "${#@}" -lt 4 ]; then
        \\printf >&2 '%s:\\n\\t%s %s %s %s %s\\n' \\
          'Usage' "$(/usr/bin/basename -- "$0")" \\
          '[OP_VAULT]' '[OP_ITEM]' \\
          '[ACCESS_KEY_ID_FIELDNAME]' '[SECRET_ACCESS_KEY_FIELDNAME]' \\
          'Example' "$(/usr/bin/basename -- "$0")" \\
          'ha4b0y7mdawmlpp2ywsdke57f7' 'nd9a4myjpgsqdbx4bakqb6aczw' \\
          "'Access Key ID'" "'Secret Access Key'"
          \\exit 1
      fi

      OP_VAULT="${1?}"
      OP_ITEM="${2?}"
      ACCESS_KEY_ID_FIELDNAME="${3?}"
      SECRET_ACCESS_KEY_FIELDNAME="${4?}"

      if [ "$(op --version | cut -d . -f 1)" -le '1' ]; then
        # 1Password CLI v1
        op get item --cache \
          --fields "${ACCESS_KEY_ID_FIELDNAME},${SECRET_ACCESS_KEY_FIELDNAME}" \
          --vault "${OP_VAULT}" \
          "${OP_ITEM}" \
          | jq '
            {
              Version: 1,
              AccessKeyId: ."${ACCESS_KEY_ID_FIELDNAME}",
              SecretAccessKey: ."${SECRET_ACCESS_KEY_FIELDNAME}",
            }'
      else
        # 1Password CLI v2 or newer
        op item get --cache \
          --fields "label=${ACCESS_KEY_ID_FIELDNAME},label=${SECRET_ACCESS_KEY_FIELDNAME}" \
          --format 'json' \
          --vault "${OP_VAULT}" \
          "${OP_ITEM}" \
          | jq '
            {
              Version: 1,
              AccessKeyId: .[0].value,
              SecretAccessKey: .[1].value
            }'
      fi
    EOS
  end

  test do
    _, stderr, = Open3.capture3(
      "#{bin}/op-aws-credentials-client", "foo", "bar", "baz", "qux"
    )
    assert_match(/The account details you entered aren't saved on this device/, stderr)
  end
end
