defmodule Huai.Python do
  use Snex.Interpreter,
    pyproject_toml: """
    [project]
    name = "idk"
    version = "0.0.0"
    requires-python = "==3.10.*"
    dependencies = ["markitdown[all]"]
    """

  def convert(filepath) do
    {:ok, env} = Snex.make_env(__MODULE__, %{"filepath" => filepath})

    Snex.pyeval(
      env,
      """
      md = MarkItDown(enable_plugins=False)
      result = md.convert(filepath)
      return result.text_content
      """, timeout: 300_000)
  end
end
