function media_player(path::AbstractString; mode::String="audio", fs::Union{Nothing, Int}=nothing)
    # Словарь поддерживаемых форматов и соответствующих им функций кодирования
    ext_map = Dict(
        # Аудио: WAV (с обработкой) и MP3 (как есть)
        "audio" => ([".wav", ".mp3"], (f -> base64encode_audio(f, fs))),
        # Видео: только MP4
        "video" => ([".mp4"], base64encode_video),
        # Изображения: основные форматы
        "image" => ([".jpg", ".jpeg", ".png", ".gif", ".webp"], base64encode_image)
    )
    
    # Проверка корректности режима работы
    haskey(ext_map, mode) || error("Неподдерживаемый режим: $mode")
    # Получаем список расширений и функцию-кодировщик для выбранного режима
    supported_extensions, encoder = ext_map[mode]
    # Получаем список файлов (один файл или все файлы из директории)
    files = isdir(path) ? readdir(path, join=true) : [path]
    # Фильтруем файлы по поддерживаемым расширениям
    selected_files = filter(f -> any(endswith(lowercase(f), ext) for ext in supported_extensions), files)
    isempty(selected_files) && error("Файлы формата $mode не найдены по указанному пути.")
    # Подготавливаем метаданные для отображения
    filenames = [basename(f) for f in selected_files]
    # Кодируем все файлы в base64 и получаем их MIME-типы
    encoded_data = [encoder(f) for f in selected_files]
    base64_encoded = [data[1] for data in encoded_data]
    mime_types = [data[2] for data in encoded_data]
    # Генерируем уникальный ID для элементов HTML (для поддержки нескольких плееров)
    unique_id = string(rand(UInt))
    # Настраиваем стили в зависимости от типа контента
    bg_color = "#f5f5f5"  # единый цвет фона для всех типов медиа
    text_color = "#555"   # единый цвет текста для всех типов медиа
    # Определяем HTML-тег в зависимости от типа медиа
    media_tag_name = mode == "audio" ? "audio" : mode == "video" ? "video" : "img"
    # Добавляем элементы управления для аудио/видео
    controls_attr = mode in ["audio", "video"] ? "controls autoplay" : ""
    # Генерируем HTML для медиа-элемента
    media_html = if mode == "image"
        # Тег img для изображений
        """<img id="$(media_tag_name)_$(unique_id)" src="data:$(mime_types[1]);base64,$(base64_encoded[1])" 
           style="max-width: 100%; border-radius: 10px;" />"""
    else
        # Теги audio/video с source внутри
        """
        <$media_tag_name id="$(media_tag_name)_$(unique_id)" $controls_attr style="width: 100%; border-radius: 10px;">
            <source id="src_$(unique_id)" src="data:$(mime_types[1]);base64,$(base64_encoded[1])" type="$(mime_types[1])" />
        </$media_tag_name>
        """
    end
    # Генерируем полный HTML-код плеера с элементами управления
    html_interface = """
    <div style="background: $bg_color; border-radius: 15px; padding: 15px; max-width: 640px; margin: 0 auto;">
        <!-- Панель управления с кнопками и именем файла -->
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; font-size: 14px; color: $text_color;">
            <!-- Кнопка "назад" -->
            <button id="prevBtn_$(unique_id)" style="background: none; border: none; cursor: pointer; font-size: 22px;">⏮️</button>
            <!-- Имя текущего файла -->
            <span id="name_$(unique_id)" style="font-weight: bold;">$(filenames[1]) (1 of $(length(filenames)))</span>
            <!-- Кнопка "вперед" -->
            <button id="nextBtn_$(unique_id)" style="background: none; border: none; cursor: pointer; font-size: 22px;">⏭️</button>
            <!-- Дополнительная кнопка цикла для аудио -->
            $(mode == "audio" ? """<button id="loopToggle_$(unique_id)" style="background: none; border: none; cursor: pointer; font-size: 20px;" title="Toggle Loop">🔂</button>""" : "")
        </div>
        <!-- Основной медиа-элемент -->
        $media_html
    </div>
    
    <!-- JavaScript для управления плеером -->
    <script>
        // Текущий индекс файла
        let currentIndex_$(unique_id) = 0;
        // Данные файлов в base64
        const mediaFiles_$(unique_id) = [$(join(["\"$(e)\"" for e in base64_encoded], ","))];
        // MIME-типы файлов
        const mimeTypes_$(unique_id) = [$(join(["\"$(m)\"" for m in mime_types], ","))];
        // Имена файлов
        const fileNames_$(unique_id) = [$(join(["\"$(n)\"" for n in filenames], ","))];
        // Флаг циклического воспроизведения
        let loopEnabled_$(unique_id) = false;
        // Получаем DOM-элементы
        const mediaElement_$(unique_id) = document.getElementById("$(media_tag_name)_$(unique_id)");
        const sourceElement_$(unique_id) = document.getElementById("src_$(unique_id)");
        const nameElement_$(unique_id) = document.getElementById("name_$(unique_id)");
        /**
         * Функция обновления текущего медиа-файла
         * @param newIndex - индекс нового файла
         */
        function updateMedia_$(unique_id)(newIndex) {
            // Корректируем индекс при выходе за границы
            if (newIndex < 0) newIndex = mediaFiles_$(unique_id).length - 1;
            if (newIndex >= mediaFiles_$(unique_id).length) newIndex = 0;
            currentIndex_$(unique_id) = newIndex;
            const currentMime = mimeTypes_$(unique_id)[newIndex];
            const mediaData = "data:" + currentMime + ";base64," + mediaFiles_$(unique_id)[newIndex];
            // Обновляем в зависимости от типа медиа
            if ("$mode" === "image") {
                // Для изображений просто меняем src
                mediaElement_$(unique_id).src = mediaData;
            } else {
                // Для аудио/видео обновляем source и запускаем воспроизведение
                sourceElement_$(unique_id).src = mediaData;
                sourceElement_$(unique_id).type = currentMime;
                mediaElement_$(unique_id).load();
                mediaElement_$(unique_id).play();
            }
            // Обновляем отображаемое имя файла
            nameElement_$(unique_id).innerText = fileNames_$(unique_id)[newIndex] + 
                " (" + (newIndex + 1) + " of " + mediaFiles_$(unique_id).length + ")";
        }
        // Назначаем обработчики кнопок
        document.getElementById("prevBtn_$(unique_id)").onclick = function() {
            updateMedia_$(unique_id)(currentIndex_$(unique_id) - 1);
        };
        document.getElementById("nextBtn_$(unique_id)").onclick = function() {
            updateMedia_$(unique_id)(currentIndex_$(unique_id) + 1);
        };
        // Дополнительные функции для аудио
        $(mode == "audio" ? """
        const loopButton_$(unique_id) = document.getElementById("loopToggle_$(unique_id)");
        // Обработчик кнопки цикла
        loopButton_$(unique_id).onclick = function() {
            loopEnabled_$(unique_id) = !loopEnabled_$(unique_id);
            loopButton_$(unique_id).innerHTML = loopEnabled_$(unique_id) ? "🔁" : "🔂";
            loopButton_$(unique_id).style.color = loopEnabled_$(unique_id) ? "dodgerblue" : "";
        };
        // Обработчик окончания воспроизведения
        mediaElement_$(unique_id).addEventListener("ended", function() {
            if (loopEnabled_$(unique_id)) {
                updateMedia_$(unique_id)(currentIndex_$(unique_id) + 1);
            }
        });
        """ : "")
    </script>
    """
    # Отображаем сгенерированный HTML
    display("text/html", html_interface)
end

# Кодирует аудиофайл в base64 с возможной передискретизацией (для WAV).
function base64encode_audio(filepath, fs)
    ext = lowercase(splitext(filepath)[2])
    if ext == ".wav"
        # Чтение WAV-файла
        audio_data, original_fs = wavread(filepath)
        # Нормализация данных (моно/стерео)
        audio_data = ndims(audio_data) == 1 ? reshape(audio_data, :, 1) : audio_data
        audio_data = clamp.(audio_data, -1, 1)  # Ограничение амплитуды
        # Конвертация в 16-битный целочисленный формат
        audio_int = round.(Int16, audio_data .* typemax(Int16))
        # Запись в буфер с новой частотой дискретизации (если указана)
        buffer = IOBuffer()
        wavwrite(audio_int, buffer; Fs=fs === nothing ? original_fs : fs, nbits=16)
        seekstart(buffer)
        # Кодирование в base64
        return base64encode(take!(buffer)), "audio/wav"
    elseif ext == ".mp3"
        # MP3 кодируется как есть
        return base64encode(read(filepath)), "audio/mpeg"
    else
        error("Неподдерживаемый аудиоформат: $ext")
    end
end

function base64encode_video(filepath) # Кодирует видеофайл (MP4) в base64.
    lowercase(splitext(filepath)[2]) == ".mp4" || error("Поддерживается только MP4")
    return base64encode(read(filepath)), "video/mp4"
end

function base64encode_image(filepath) # Кодирует изображение в base64.
    ext = lowercase(splitext(filepath)[2])
    # Определяем MIME-тип по расширению
    mime_type = if ext == ".jpg" || ext == ".jpeg"
        "image/jpeg"
    elseif ext == ".png"
        "image/png"
    elseif ext == ".gif"
        "image/gif"
    elseif ext == ".webp"
        "image/webp"
    else
        error("Неподдерживаемый формат изображения: $ext")
    end
    return base64encode(read(filepath)), mime_type
end