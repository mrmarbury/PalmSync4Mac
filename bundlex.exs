defmodule PalmSync4Mac.BundlexProject do
use Bundlex.Project

def project do
 [
    natives: natives(Bundlex.get_target()),
 ]
end

def natives(_platform) do
 [
   pidlp: [
     sources: ["pidlp.c"],
     interface: [:nif],
     preprocessor: Unifex,
     includes: ["/opt/homebrew/include"],
     libs: ["pisock"],                         # <-- link to libpisock
     lib_dirs: ["/opt/homebrew/lib"]           # <-- path to libpisock.dylib
   ],
 ]
end
end
