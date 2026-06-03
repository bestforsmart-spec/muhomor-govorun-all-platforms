package com.shromspeak.app;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.UUID;

public class MainActivity extends Activity implements TextToSpeech.OnInitListener {
    private static final String PREFS = "muhomor_govorun";
    private EditText textInput;
    private EditText saluteKeyInput;
    private EditText elevenLabsKeyInput;
    private TextView status;
    private RadioGroup voiceGroup;
    private TextToSpeech localTts;
    private MediaPlayer player;
    private SharedPreferences prefs;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        localTts = new TextToSpeech(this, this);
        buildUi();
        consumeSharedText(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        consumeSharedText(intent);
    }

    @Override
    public void onInit(int statusCode) {
        if (statusCode == TextToSpeech.SUCCESS) {
            localTts.setLanguage(new Locale("ru", "RU"));
        }
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(28, 24, 28, 20);
        root.setBackgroundColor(0xFFF7F7F3);

        TextView title = new TextView(this);
        title.setText("Мухомор - Говорун");
        title.setTextSize(24);
        title.setTextColor(0xFF141412);
        root.addView(title);

        status = new TextView(this);
        status.setText("Готов");
        status.setTextColor(0xFF42615B);
        status.setPadding(0, 6, 0, 12);
        root.addView(status);

        voiceGroup = new RadioGroup(this);
        voiceGroup.setOrientation(RadioGroup.VERTICAL);
        addVoice("Локальная простая быстрая модель", "local_fast");
        addVoice("SaluteSpeech быстрый облачный", "salute_tts");
        addVoice("ElevenLabs красивый голос", "elevenlabs_tts");
        String backend = prefs.getString("tts_backend", "local_fast");
        RadioButton checked = voiceGroup.findViewWithTag(backend);
        if (checked != null) checked.setChecked(true);
        voiceGroup.setOnCheckedChangeListener((group, checkedId) -> {
            View view = group.findViewById(checkedId);
            if (view != null) prefs.edit().putString("tts_backend", String.valueOf(view.getTag())).apply();
        });
        root.addView(voiceGroup);

        textInput = new EditText(this);
        textInput.setMinLines(10);
        textInput.setGravity(Gravity.TOP | Gravity.START);
        textInput.setTextSize(17);
        textInput.setHint("Вставьте текст или поделитесь текстом из другого приложения");
        root.addView(textInput, new LinearLayout.LayoutParams(-1, 0, 1));

        TextView settingsTitle = new TextView(this);
        settingsTitle.setText("Ключи");
        settingsTitle.setTextSize(16);
        settingsTitle.setTextColor(0xFF141412);
        settingsTitle.setPadding(0, 12, 0, 4);
        root.addView(settingsTitle);

        saluteKeyInput = new EditText(this);
        saluteKeyInput.setSingleLine(true);
        saluteKeyInput.setHint("SaluteSpeech auth key");
        saluteKeyInput.setText(prefs.getString("salute_auth_key", ""));
        root.addView(saluteKeyInput);

        elevenLabsKeyInput = new EditText(this);
        elevenLabsKeyInput.setSingleLine(true);
        elevenLabsKeyInput.setHint("ElevenLabs API key");
        elevenLabsKeyInput.setText(prefs.getString("elevenlabs_api_key", ""));
        root.addView(elevenLabsKeyInput);

        LinearLayout buttons = new LinearLayout(this);
        buttons.setOrientation(LinearLayout.HORIZONTAL);
        buttons.setPadding(0, 12, 0, 0);
        Button paste = new Button(this);
        paste.setText("Буфер");
        paste.setOnClickListener(v -> pasteClipboard());
        buttons.addView(paste, new LinearLayout.LayoutParams(0, -2, 1));
        Button speak = new Button(this);
        speak.setText("Озвучить");
        speak.setOnClickListener(v -> speak());
        buttons.addView(speak, new LinearLayout.LayoutParams(0, -2, 1));
        Button stop = new Button(this);
        stop.setText("Стоп");
        stop.setOnClickListener(v -> stopSpeech());
        buttons.addView(stop, new LinearLayout.LayoutParams(0, -2, 1));
        Button save = new Button(this);
        save.setText("Сохранить");
        save.setOnClickListener(v -> saveKeys());
        buttons.addView(save, new LinearLayout.LayoutParams(0, -2, 1));
        root.addView(buttons);

        TextView configHint = new TextView(this);
        configHint.setText("Ключи хранятся локально в SharedPreferences и не входят в репозиторий.");
        configHint.setTextColor(0xFF6B6B62);
        configHint.setPadding(0, 12, 0, 0);
        root.addView(configHint);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(root);
        setContentView(scroll);
    }

    private void addVoice(String title, String value) {
        RadioButton rb = new RadioButton(this);
        rb.setText(title);
        rb.setTag(value);
        rb.setId(View.generateViewId());
        voiceGroup.addView(rb);
    }

    private void consumeSharedText(Intent intent) {
        if (Intent.ACTION_SEND.equals(intent.getAction()) && "text/plain".equals(intent.getType())) {
            String shared = intent.getStringExtra(Intent.EXTRA_TEXT);
            if (shared != null) textInput.setText(shared);
        }
    }

    private void pasteClipboard() {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        ClipData clip = clipboard.getPrimaryClip();
        if (clip != null && clip.getItemCount() > 0) {
            CharSequence value = clip.getItemAt(0).coerceToText(this);
            if (value != null) textInput.setText(value.toString());
        }
    }

    private void speak() {
        saveKeys();
        String text = textInput.getText().toString().trim();
        if (text.isEmpty()) {
            Toast.makeText(this, "Введите текст", Toast.LENGTH_SHORT).show();
            return;
        }
        RadioButton selected = findViewById(voiceGroup.getCheckedRadioButtonId());
        String backend = selected == null ? "local_fast" : String.valueOf(selected.getTag());
        prefs.edit().putString("tts_backend", backend).apply();
        stopSpeech();
        if ("salute_tts".equals(backend)) {
            runCloud(() -> speakSalute(text));
        } else if ("elevenlabs_tts".equals(backend)) {
            runCloud(() -> speakElevenLabs(text));
        } else {
            setStatus("Озвучиваю локально");
            localTts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "muhomor-local");
        }
    }

    private void saveKeys() {
        prefs.edit()
            .putString("salute_auth_key", saluteKeyInput.getText().toString().trim())
            .putString("elevenlabs_api_key", elevenLabsKeyInput.getText().toString().trim())
            .apply();
        Toast.makeText(this, "Настройки сохранены", Toast.LENGTH_SHORT).show();
    }

    private void runCloud(ThrowingRunnable runnable) {
        new Thread(() -> {
            try {
                runnable.run();
                runOnUiThread(() -> setStatus("Готов"));
            } catch (Exception ex) {
                runOnUiThread(() -> {
                    setStatus("Ошибка");
                    Toast.makeText(this, ex.getMessage(), Toast.LENGTH_LONG).show();
                });
            }
        }).start();
    }

    private void speakSalute(String text) throws Exception {
        String authKey = prefs.getString("salute_auth_key", "");
        if (authKey.isEmpty()) throw new IllegalStateException("SaluteSpeech ключ не задан");
        setStatusThread("Получаю токен SaluteSpeech");
        String scope = prefs.getString("salute_scope", "SALUTE_SPEECH_PERS");
        HttpURLConnection tokenConn = (HttpURLConnection) new URL("https://ngw.devices.sberbank.ru:9443/api/v2/oauth").openConnection();
        tokenConn.setRequestMethod("POST");
        tokenConn.setDoOutput(true);
        tokenConn.setRequestProperty("Authorization", "Basic " + authKey);
        tokenConn.setRequestProperty("RqUID", UUID.randomUUID().toString());
        tokenConn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
        tokenConn.getOutputStream().write(("scope=" + URLEncoder.encode(scope, "UTF-8")).getBytes(StandardCharsets.UTF_8));
        String tokenJson = new String(tokenConn.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        String token = new JSONObject(tokenJson).getString("access_token");

        setStatusThread("Генерирую SaluteSpeech");
        String voice = prefs.getString("salute_voice", "Ost_24000");
        String url = "https://smartspeech.sber.ru/rest/v1/text:synthesize?format=wav16&voice=" + URLEncoder.encode(voice, "UTF-8");
        HttpURLConnection synth = (HttpURLConnection) new URL(url).openConnection();
        synth.setRequestMethod("POST");
        synth.setDoOutput(true);
        synth.setRequestProperty("Authorization", "Bearer " + token);
        synth.setRequestProperty("Content-Type", "application/text");
        synth.getOutputStream().write(text.getBytes(StandardCharsets.UTF_8));
        playBytes(synth.getInputStream().readAllBytes(), ".wav");
    }

    private void speakElevenLabs(String text) throws Exception {
        String apiKey = prefs.getString("elevenlabs_api_key", "");
        if (apiKey.isEmpty()) throw new IllegalStateException("ElevenLabs ключ не задан");
        setStatusThread("Генерирую ElevenLabs");
        String voiceId = prefs.getString("elevenlabs_voice_id", "JBFqnCBsd6RMkjVDRZzb");
        JSONObject payload = new JSONObject();
        payload.put("text", text);
        payload.put("model_id", prefs.getString("elevenlabs_model_id", "eleven_multilingual_v2"));
        JSONObject settings = new JSONObject();
        settings.put("stability", 0.48);
        settings.put("similarity_boost", 0.78);
        settings.put("style", 0.18);
        settings.put("use_speaker_boost", true);
        payload.put("voice_settings", settings);
        String url = "https://api.elevenlabs.io/v1/text-to-speech/" + URLEncoder.encode(voiceId, "UTF-8") + "?output_format=mp3_44100_128";
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("xi-api-key", apiKey);
        conn.setRequestProperty("Content-Type", "application/json");
        conn.getOutputStream().write(payload.toString().getBytes(StandardCharsets.UTF_8));
        playBytes(conn.getInputStream().readAllBytes(), ".mp3");
    }

    private void playBytes(byte[] bytes, String suffix) throws Exception {
        File file = File.createTempFile("muhomor-voice", suffix, getCacheDir());
        try (OutputStream out = new FileOutputStream(file)) {
            out.write(bytes);
        }
        runOnUiThread(() -> setStatus("Воспроизвожу"));
        player = MediaPlayer.create(this, Uri.fromFile(file));
        player.setOnCompletionListener(mp -> {
            mp.release();
            file.delete();
            setStatus("Готов");
        });
        player.start();
    }

    private void stopSpeech() {
        if (localTts != null) localTts.stop();
        if (player != null) {
            player.stop();
            player.release();
            player = null;
        }
        setStatus("Остановлено");
    }

    private void setStatus(String value) {
        status.setText(value);
    }

    private void setStatusThread(String value) {
        runOnUiThread(() -> setStatus(value));
    }

    @Override
    protected void onDestroy() {
        stopSpeech();
        if (localTts != null) localTts.shutdown();
        super.onDestroy();
    }

    private interface ThrowingRunnable {
        void run() throws Exception;
    }
}
