defmodule OcrApp.OCR do
  require Logger

  def extract_text(image_path, options \\ []) do
    language = if options[:detect_language], do: "auto", else: options[:language] || "eng"
    psm = options[:psm] || 4

    lang_param = case language do
      "auto" -> "-l kor+eng"
      "kor" -> "-l kor+eng"
      "eng" -> "-l eng"
      "jpn" -> "-l jpn"
      "chn" -> "-l chi_sim"
      _ -> "-l eng"
    end

    {:ok, output_file} = Temp.path(%{suffix: ".txt"})

    ocr_config = if language == "kor" || language == "auto" do
      "--oem 1 --psm #{psm} -c preserve_interword_spaces=1"
    else
      "--oem 1 --psm #{psm} -c preserve_interword_spaces=1"
    end

    command = "tesseract \"#{image_path}\" \"#{output_file}\" #{lang_param} #{ocr_config} txt"

    Logger.info("실행 명령어: #{command}")

    case System.shell(command) do
      {_, 0} ->
        output_path = "#{output_file}.txt"

        if File.exists?(output_path) do
          text = File.read!(output_path)
          formatted_text = format_ocr_text(text)
          File.rm(output_path)

          {:ok, formatted_text}
        else
          {:error, "OCR 처리 결과 파일을 찾을 수 없습니다."}
        end

      {error, _} ->
        Logger.error("OCR 처리 중 오류 발생: #{inspect(error)}")
        {:error, "OCR 처리 중 오류가 발생했습니다."}
    end
  end

  defp format_ocr_text(text) do
    String.replace(text, ~r/\r\n/, "\n")
  end

  def preprocess_image(image_path, options \\ []) do
    language = options[:language] || "eng"

    try do
      case System.cmd("which", ["convert"], stderr_to_stdout: true) do
        {_, 0} ->
          case language do
            "kor" -> preprocess_for_korean(image_path)
            "auto" -> preprocess_for_korean(image_path)
            _ -> default_preprocess(image_path)
          end
        _ ->
          Logger.warning("ImageMagick이 설치되어 있지 않아 이미지 전처리를 건너뜁니다.")
          {:ok, image_path}
      end
    rescue
      e ->
        Logger.error("이미지 전처리 중 오류 발생: #{inspect(e)}")
        Logger.error("스택 트레이스: #{Exception.format_stacktrace(__STACKTRACE__)}")
        {:ok, image_path}
    end
  end

  defp preprocess_for_korean(image_path) do
    {:ok, output_path} = Temp.path(%{suffix: ".png"})

    command = "convert \"#{image_path}\" -colorspace gray -normalize -despeckle -deskew 40% +repage -background white -alpha remove -alpha off \"#{output_path}\""

    Logger.info("전처리 명령어: #{command}")

    case System.shell(command) do
      {_, 0} ->
        if File.exists?(output_path) do
          enhance_image(output_path)
        else
          Logger.error("이미지 전처리 결과 파일을 찾을 수 없습니다.")
          {:ok, image_path}
        end
      {error, _} ->
        Logger.error("이미지 전처리 중 오류 발생: #{inspect(error)}")
        {:ok, image_path}
    end
  end

  defp default_preprocess(image_path) do
    {:ok, output_path} = Temp.path(%{suffix: ".png"})

    command = "convert \"#{image_path}\" -colorspace gray -normalize \"#{output_path}\""

    Logger.info("전처리 명령어: #{command}")

    case System.shell(command) do
      {_, 0} ->
        if File.exists?(output_path) do
          {:ok, output_path}
        else
          Logger.error("이미지 전처리 결과 파일을 찾을 수 없습니다.")
          {:ok, image_path}
        end
      {error, _} ->
        Logger.error("이미지 전처리 중 오류 발생: #{inspect(error)}")
        {:ok, image_path}
    end
  end

  defp enhance_image(image_path) do
    {:ok, output_path} = Temp.path(%{suffix: ".png"})

    command = "convert \"#{image_path}\" -sharpen 0x1.0 -contrast -quality 100 \"#{output_path}\""

    Logger.info("이미지 선명화 명령어: #{command}")

    case System.shell(command) do
      {_, 0} ->
        if File.exists?(output_path) do
          File.rm(image_path)
          {:ok, output_path}
        else
          Logger.error("이미지 선명화 결과 파일을 찾을 수 없습니다.")
          {:ok, image_path}
        end
      {error, _} ->
        Logger.error("이미지 선명화 중 오류 발생: #{inspect(error)}")
        {:ok, image_path}
    end
  end
end
