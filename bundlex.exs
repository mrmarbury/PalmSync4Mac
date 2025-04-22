defmodule PalmSync4Mac.BundlexProject do
use Bundlex.Project

def project do
 [
   natives: natives(Bundlex.platform())
 ]
end

def natives(_platform) do
 [
   libpisock: [
     sources: ["libpisock.c"],
     interface: :nif,
     preprocessor: Unifex
   ]
 ]
end
end
