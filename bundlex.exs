defmodule PalmSync4Mac.BundlexProject do
  @moduledoc false
  use Bundlex.Project

  def project do
    [
      natives: natives(Bundlex.get_target())
    ]
  end

  def natives(_platform) do
    pilot_link_include = System.get_env("PILOT_LINK_INCLUDE", "/opt/homebrew/include")
    pilot_link_lib_dir = System.get_env("PILOT_LINK_LIB_DIR", "/opt/homebrew/lib")

    [
      pidlp: [
        sources: ["pidlp.c"],
        interface: [:nif],
        preprocessor: Unifex,
        includes: [pilot_link_include],
        libs: ["pisock"],
        lib_dirs: [pilot_link_lib_dir]
      ]
    ]
  end
end
