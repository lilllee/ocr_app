defmodule OcrAppWeb.PageController do
  use OcrAppWeb, :controller
  require Logger
  alias OcrApp.OCR

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def upload_file(conn, params) do
    Logger.info("업로드 요청 수신: #{inspect(params)}")
    Logger.info("Headers: #{inspect(conn.req_headers)}")

    image = params["image"]

    if image do
      temp_dir = System.tmp_dir!()
      filename = Path.basename(image.filename)
      temp_path = Path.join(temp_dir, "f-#{System.system_time()}-#{System.pid()}-#{random_string(6)}.png")

      File.cp!(image.path, temp_path)
      Logger.info("임시 파일 생성: #{temp_path}")

      detect_language = params["detect_language"] == "true"
      language = params["language"] || "eng"

      psm = get_psm_from_params(params)

      options = %{
        detect_language: detect_language,
        language: language,
        psm: psm
      }

      Logger.info("이미지 처리 시작: #{filename}, 옵션: #{inspect(options)}")

      process_image(conn, temp_path, options)
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{
        success: false,
        error: "이미지가 필요합니다"
      })
    end
  end

  defp process_image(conn, image_path, options) do
    {:ok, processed_path} = OcrApp.OCR.preprocess_image(image_path, options)

    case OcrApp.OCR.extract_text(processed_path, options) do
      {:ok, text} ->
        Logger.info("OCR 텍스트 추출 성공, 길이: #{String.length(text)}")

        File.rm(image_path)
        Logger.info("임시 파일 삭제: #{image_path}")

        if image_path != processed_path do
          File.rm(processed_path)
          Logger.info("임시 파일 삭제: #{processed_path}")
        end

        conn
        |> json(%{
          success: true,
          text: text,
          language: options.language,
          psm: options.psm
        })

      {:error, reason} ->
        Logger.error("OCR 처리 중 오류 발생: #{reason}")

        File.rm(image_path)

        if image_path != processed_path do
          File.rm(processed_path)
        end

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: reason
        })
    end
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  defp get_psm_from_params(params) do
    psm_string = params["psm"]

    cond do
      is_nil(psm_string) ->
        4

      is_binary(psm_string) ->
        case Integer.parse(psm_string) do
          {psm, _} when psm >= 0 and psm <= 13 ->
            psm
          _ ->
            4
        end

      true ->
        4
    end
  end

  defp valid_image_extension?(filename) do
    ext = filename |> Path.extname() |> String.downcase()
    Enum.member?([".jpg", ".jpeg", ".png", ".gif", ".tiff", ".tif", ".bmp"], ext)
  end

  defp clean_up_files(file_paths) do
    Enum.each(file_paths, fn path ->
      if File.exists?(path) do
        File.rm(path)
        Logger.info("임시 파일 삭제: #{path}")
      end
    end)
  end
end
