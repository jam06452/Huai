defmodule Huai.Python do
  use Snex.Interpreter,
    pyproject_toml: """
    [project]
    name = "idk"
    version = "0.0.0"
    requires-python = "==3.10.*"
    dependencies = ["markitdown[all]", "openai"]
    """

  def convert(filepath) do
    config = Application.get_env(:huai, :ai)

    {:ok, env} =
      Snex.make_env(__MODULE__, %{
        "filepath" => filepath,
        "base_url" => config[:url],
        "api_key" => config[:key]
      })

    Snex.pyeval(
      env,
      """
      from openai import OpenAI
      from markitdown import MarkItDown
      client = OpenAI(
          api_key=api_key,
          base_url=base_url
      )
      md = MarkItDown(
          enable_plugins=True,
          llm_client=client,
          llm_model="gpt-4o"
      )
      result = md.convert(filepath)
      return result.text_content
      """,
      timeout: 300_000
    )
  end
end
