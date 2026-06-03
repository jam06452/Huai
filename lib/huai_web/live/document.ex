defmodule HuaiWeb.DocumentLive do
  require Logger
  use HuaiWeb, :live_view

  @impl true

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:markdown_result, nil)
      |> assign(:upload_progress, 0)
      |> allow_upload(:document,
        accept: ~w(.txt .md .pdf .png),
        auto_upload: true,
        max_file_size: 100_000_000_000,
        chunk_size: 1024_000,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-change="validate" phx-submit="save">
      <.live_file_input upload={@uploads.document} class="file-input" />
    </form>

    <button
      phx-click={JS.dispatch("phx:copy", to: "#control-codes")}
      class="btn btn-xs sm:btn-sm md:btn-md lg:btn-lg xl:btn-xl"
    >
      Copy
    </button>

    <%= if @upload_progress > 0 and @upload_progress < 100 do %>
      <div class="mt-4">
        <p class="text-sm mb-1">Uploading... {@upload_progress}%</p>
        <progress class="progress progress-primary w-full" value={@upload_progress} max="100" />
      </div>
    <% end %>

    <%= if @upload_progress >= 98 and is_nil(@markdown_result) do %>
      <p>Loading</p>
      <span class="loading loading-spinner loading-xs"></span>
    <% end %>

    <%= if @markdown_result do %>
      <div class="mt-8 p-6 bg-base-200 rounded-lg shadow prose max-w-none dark:prose-invert">
        <input type="text" id="control-codes" value={@markdown_result} class="hidden" />
        {raw(MDEx.to_html!(@markdown_result))}
      </div>
    <% end %>
    """
  end

  @impl true

  #
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  defp handle_progress(:document, entry, socket) do
    if entry.done? do
      socket_pid = self()

      [path] =
        consume_uploaded_entries(socket, :document, fn %{path: path}, _info ->
          dest_path = Path.join(System.tmp_dir!(), "doc_#{System.unique_integer([:positive])}")
          File.cp!(path, dest_path)
          {:ok, dest_path}
        end)

      Task.start(fn ->
        case Huai.Python.convert(path) do
          {:ok, markdown} ->
            send(socket_pid, {:conversion_done, markdown})

          {:error, reason} ->
            Logger.warning(reason)
            send(socket_pid, {:conversion_error, reason})
        end
      end)

      {:noreply, assign(socket, :upload_progress, 100)}
    else
      {:noreply, assign(socket, :upload_progress, entry.progress)}
    end
  end

  @impl true
  def handle_info({:conversion_done, markdown}, socket) do
    {:noreply, assign(socket, :markdown_result, markdown)}
  end

  @impl true
  def handle_info({:conversion_error, _reason}, socket) do
    {:noreply, assign(socket, :markdown_result, "Conversion failed, please try again.")}
  end
end
