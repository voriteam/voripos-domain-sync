class VoriposDomainData < Formula
  url "file:///Users/clintonb/workspace/vori/vori-pos/data-synchronization/domain-data/domain-data.tar.gz"
  version "0.0.1"
  sha256 "09066ceae4e8f4241b10690037864def81439017db80812becc99ae5af6355ad"
  def install
    # Move everything under #{libexec}/
    libexec.install Dir["*"]

    # Then write executables under #{bin}/
    bin.write_exec_script (libexec/"voripos-domain-sync.sh")
  end

  service do
    run opt_bin/"voripos-domain-sync.sh"
    keep_alive true
  end
end
