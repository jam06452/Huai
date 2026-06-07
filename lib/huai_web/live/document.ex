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
        accept:
          ~w(.txt .md .pdf .docx .pptx .xlsx .epub .html .htm .csv .json .xml .png .jpg .jpeg .gif .bmp .tiff .webp .mp3 .wav .mp4 .mov .avi .webm .zip),
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
    <div class="min-h-screen bg-base-100 flex flex-col items-center px-4 py-16">
      <%!-- Header --%>
      <div class="mb-12 text-center">
        <h1 class="text-4xl font-bold tracking-tight mb-2">Document Converter</h1>
        <p class="text-base-content/50 text-sm">Upload any file to convert it to clean Markdown</p>
      </div>

      <%!-- Upload Card --%>
      <div class="card bg-base-200 border border-base-300 shadow-sm w-full max-w-2xl">
        <div class="card-body gap-6">
          <form id="upload-form" phx-change="validate" phx-submit="save">
            <label class="flex flex-col items-center justify-center w-full h-48 border-2 border-dashed border-base-300 rounded-xl cursor-pointer hover:border-primary hover:bg-base-300/40 transition-all duration-200 group">
              <div class="flex flex-col items-center gap-3 pointer-events-none">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-10 h-10 text-base-content/30 group-hover:text-primary transition-colors duration-200"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="1.5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 16V4m0 0L8 8m4-4l4 4M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1"
                  />
                </svg>
                <div class="text-center">
                  <p class="text-sm font-medium text-base-content/70 group-hover:text-base-content transition-colors">
                    Drop a file or click to browse
                  </p>
                  <p class="text-xs text-base-content/40 mt-1">
                    PDF, DOCX, PPTX, XLSX, images, audio, video & more
                  </p>
                </div>
              </div>
              <.live_file_input upload={@uploads.document} class="hidden" />
            </label>
          </form>

          <%!-- Upload Progress --%>
          <%= if @upload_progress > 0 and @upload_progress < 100 do %>
            <div class="flex flex-col gap-1.5">
              <div class="flex justify-between text-xs text-base-content/50">
                <span>Uploading</span>
                <span>{@upload_progress}%</span>
              </div>
              <progress class="progress progress-primary w-full" value={@upload_progress} max="100" />
            </div>
          <% end %>

          <%!-- Processing State --%>
          <%= if @upload_progress >= 98 and is_nil(@markdown_result) do %>
            <div class="flex items-center gap-3 text-sm text-base-content/60">
              <span class="loading loading-spinner loading-sm text-primary"></span>
              <span>Converting document…</span>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Result Card --%>
      <%= if @markdown_result do %>
        <div class="mt-8 w-full max-w-2xl">
          <div class="flex items-center justify-between mb-3">
            <span class="text-xs font-semibold uppercase tracking-widest text-base-content/40">
              Result
            </span>
            <button
              phx-click={JS.dispatch("phx:copy", to: "#control-codes")}
              class="btn btn-sm btn-ghost gap-2"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-4 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                />
              </svg>
              Copy Markdown
            </button>
          </div>
          <div class="card bg-base-200 border border-base-300 shadow-sm">
            <div class="card-body">
              <input type="text" id="control-codes" value={@markdown_result} class="hidden" />
              <div class="prose prose-sm max-w-none dark:prose-invert">
                {raw(MDEx.to_html!(@markdown_result))}
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
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
