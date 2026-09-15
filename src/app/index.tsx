import { useRouter, useTheme } from 'expo-router';
import { type ComponentRef, useRef, useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { RechiboxLogo } from '@/components/RechiboxLogo';
import {
  askWorld,
  getWorldQueryConfiguration,
  WorldQueryClientError,
  type WorldQueryAnswerStatus,
} from '@/world-query/client';

type ChatMessage = {
  id: number;
  role: 'user' | 'assistant';
  text: string;
  status?: WorldQueryAnswerStatus;
};

export default function HomeScreen() {
  const { colors } = useTheme();
  const router = useRouter();
  const scrollViewRef = useRef<ComponentRef<typeof ScrollView>>(null);
  const nextMessageId = useRef(1);
  const [draft, setDraft] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isSending, setIsSending] = useState(false);
  const configuration = getWorldQueryConfiguration();

  const appendMessage = (message: Omit<ChatMessage, 'id'>) => {
    const id = nextMessageId.current;
    nextMessageId.current += 1;
    setMessages((current) => [...current, { id, ...message }]);
  };

  const submit = async () => {
    const message = draft.trim();
    if (!message || isSending) return;

    setDraft('');
    appendMessage({ role: 'user', text: message });
    setIsSending(true);

    try {
      const result = await askWorld(message);
      if (result.answer?.text) {
        appendMessage({
          role: 'assistant',
          text: result.answer.text,
          status: result.answer.status,
        });
      } else if (result.mode === 'disabled') {
        appendMessage({
          role: 'assistant',
          text: 'Пошук у World State зараз вимкнений на сервері. Жодних даних не змінено.',
          status: 'unavailable',
        });
      } else {
        appendMessage({
          role: 'assistant',
          text: 'Не вдалося отримати відповідь із World State.',
          status: 'unavailable',
        });
      }
    } catch (error) {
      appendMessage({
        role: 'assistant',
        text: errorMessage(error),
        status: 'unavailable',
      });
    } finally {
      setIsSending(false);
    }
  };

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: colors.background }]}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.keyboardAvoidingView}>
        <View style={[styles.header, { borderBottomColor: colors.border }]}>
          <View accessible accessibilityLabel="Rechibox" accessibilityRole="image" style={styles.logo}>
            <RechiboxLogo color={colors.text} />
          </View>
          <View style={styles.headerActions}>
            <Pressable
              accessibilityLabel="Відкрити інвентар"
              accessibilityRole="button"
              onPress={() => router.push('/inventory-list')}
              style={({ pressed }) => [
                styles.headerButton,
                { borderColor: colors.border, opacity: pressed ? 0.6 : 1 },
              ]}>
              <Text style={[styles.headerButtonText, { color: colors.text }]}>Інвентар</Text>
            </Pressable>
            <Pressable
              accessibilityLabel="Відкрити варіанти зберігання"
              accessibilityRole="button"
              onPress={() => router.push('/storage')}
              style={({ pressed }) => [
                styles.headerButton,
                { borderColor: colors.border, opacity: pressed ? 0.6 : 1 },
              ]}>
              <Text style={[styles.headerButtonText, { color: colors.text }]}>Бокси</Text>
            </Pressable>
          </View>
        </View>

        <ScrollView
          automaticallyAdjustKeyboardInsets
          contentContainerStyle={styles.messagesContent}
          keyboardDismissMode="interactive"
          keyboardShouldPersistTaps="handled"
          onContentSizeChange={() => scrollViewRef.current?.scrollToEnd({ animated: true })}
          ref={scrollViewRef}
          style={styles.messages}>
          {messages.length === 0 ? (
            <View style={styles.emptyState}>
              <Text style={[styles.title, { color: colors.text }]}>Що ви хочете знайти?</Text>
              <Text style={[styles.subtitle, { color: colors.text }]}>Запитайте про речі, коробки або місця.</Text>
              <View style={styles.examples}>
                {['Де мої кабелі?', 'Що в синій коробці?', 'Хто зберігає дриль?'].map((example) => (
                  <Pressable
                    accessibilityRole="button"
                    key={example}
                    onPress={() => setDraft(example)}
                    style={({ pressed }) => [
                      styles.example,
                      { borderColor: colors.border, opacity: pressed ? 0.65 : 1 },
                    ]}>
                    <Text style={[styles.exampleText, { color: colors.text }]}>{example}</Text>
                  </Pressable>
                ))}
              </View>
            </View>
          ) : (
            messages.map((message) => (
              <View
                key={message.id}
                style={[
                  styles.messageRow,
                  message.role === 'user' ? styles.userMessageRow : styles.assistantMessageRow,
                ]}>
                <View
                  accessible
                  accessibilityLabel={`${message.role === 'user' ? 'Ви' : 'Rechibox'}: ${message.text}`}
                  style={[
                    styles.bubble,
                    message.role === 'user'
                      ? { backgroundColor: colors.primary }
                      : { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
                  ]}>
                  <Text
                    style={[
                      styles.messageText,
                      { color: message.role === 'user' ? '#FFFFFF' : colors.text },
                    ]}>
                    {message.text}
                  </Text>
                  {message.role === 'assistant' && message.status && message.status !== 'resolved' ? (
                    <Text style={[styles.statusText, { color: colors.text }]}>{statusLabel(message.status)}</Text>
                  ) : null}
                </View>
              </View>
            ))
          )}
          {isSending ? (
            <View style={[styles.loadingBubble, { backgroundColor: colors.card, borderColor: colors.border }]}>
              <ActivityIndicator color={colors.primary} size="small" />
              <Text accessibilityLiveRegion="polite" style={[styles.loadingText, { color: colors.text }]}>
                Шукаю у World State…
              </Text>
            </View>
          ) : null}
        </ScrollView>

        <View style={[styles.composerArea, { borderTopColor: colors.border }]}>
          {!configuration.ready ? (
            <Text style={[styles.connectionNote, { color: colors.text }]}>Backend не підключено в цій збірці.</Text>
          ) : null}
          <View style={styles.composerRow}>
            <TextInput
              accessibilityLabel="Запит до Rechibox"
              blurOnSubmit={false}
              editable={!isSending}
              multiline
              onChangeText={setDraft}
              onSubmitEditing={() => void submit()}
              placeholder="Наприклад: де мої кабелі?"
              placeholderTextColor={colors.border}
              returnKeyType="send"
              style={[
                styles.input,
                { borderColor: colors.border, color: colors.text, backgroundColor: colors.card },
              ]}
              value={draft}
            />
            <Pressable
              accessibilityLabel="Надіслати запит"
              accessibilityRole="button"
              accessibilityState={{ disabled: isSending || draft.trim().length === 0 }}
              disabled={isSending || draft.trim().length === 0}
              onPress={() => void submit()}
              style={({ pressed }) => [
                styles.sendButton,
                {
                  backgroundColor: colors.primary,
                  opacity: isSending || draft.trim().length === 0 ? 0.35 : pressed ? 0.65 : 1,
                },
              ]}>
              <Text style={styles.sendButtonText}>↑</Text>
            </Pressable>
          </View>
          <Pressable accessibilityRole="button" onPress={() => router.push('/inventory')}>
            <Text style={[styles.cameraLink, { color: colors.primary }]}>Додати речі через камеру</Text>
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function errorMessage(error: unknown) {
  if (error instanceof WorldQueryClientError) {
    if (error.code === 'not_configured') {
      return 'Пошук у ваших речах поки недоступний у цій збірці.';
    }
    if (error.code === 'invalid_response') {
      return 'Backend повернув неочікувану відповідь. Спробуйте ще раз пізніше.';
    }
  }

  return 'Не вдалося зв’язатися з Rechibox. Перевірте підключення та спробуйте ще раз.';
}

function statusLabel(status: WorldQueryAnswerStatus) {
  switch (status) {
    case 'ambiguous':
      return 'Потрібне уточнення';
    case 'unknown':
      return 'Немає записаних даних';
    case 'conflict':
      return 'Конфлікт у даних';
    case 'unavailable':
      return 'Недоступно';
    default:
      return '';
  }
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  keyboardAvoidingView: {
    flex: 1,
  },
  header: {
    minHeight: 58,
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  logo: {
    width: 142,
    height: 34,
  },
  headerActions: {
    flexDirection: 'row',
    gap: 8,
  },
  headerButton: {
    minHeight: 40,
    justifyContent: 'center',
    paddingHorizontal: 12,
    borderWidth: 1,
    borderRadius: 20,
  },
  headerButtonText: {
    fontSize: 14,
    fontWeight: '600',
  },
  messages: {
    flex: 1,
  },
  messagesContent: {
    flexGrow: 1,
    paddingHorizontal: 18,
    paddingVertical: 20,
    gap: 12,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    paddingVertical: 28,
    gap: 10,
  },
  title: {
    fontSize: 30,
    lineHeight: 36,
    fontWeight: '700',
  },
  subtitle: {
    fontSize: 17,
    lineHeight: 24,
    opacity: 0.7,
  },
  examples: {
    marginTop: 14,
    gap: 10,
  },
  example: {
    alignSelf: 'flex-start',
    minHeight: 44,
    justifyContent: 'center',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderWidth: 1,
    borderRadius: 22,
  },
  exampleText: {
    fontSize: 15,
  },
  messageRow: {
    width: '100%',
  },
  userMessageRow: {
    alignItems: 'flex-end',
  },
  assistantMessageRow: {
    alignItems: 'flex-start',
  },
  bubble: {
    maxWidth: '86%',
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 11,
  },
  messageText: {
    fontSize: 16,
    lineHeight: 22,
  },
  statusText: {
    marginTop: 7,
    fontSize: 12,
    fontWeight: '600',
    opacity: 0.55,
  },
  loadingBubble: {
    alignSelf: 'flex-start',
    minHeight: 44,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 9,
    paddingHorizontal: 14,
    borderRadius: 18,
    borderWidth: 1,
  },
  loadingText: {
    fontSize: 14,
    opacity: 0.7,
  },
  composerArea: {
    paddingHorizontal: 14,
    paddingTop: 10,
    paddingBottom: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
    gap: 7,
  },
  connectionNote: {
    fontSize: 12,
    textAlign: 'center',
    opacity: 0.55,
  },
  composerRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 8,
  },
  input: {
    flex: 1,
    minHeight: 48,
    maxHeight: 120,
    paddingHorizontal: 14,
    paddingTop: 12,
    paddingBottom: 12,
    borderWidth: 1,
    borderRadius: 20,
    fontSize: 16,
    lineHeight: 21,
  },
  sendButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendButtonText: {
    color: '#FFFFFF',
    fontSize: 26,
    lineHeight: 28,
    fontWeight: '700',
  },
  cameraLink: {
    minHeight: 32,
    textAlign: 'center',
    textAlignVertical: 'center',
    fontSize: 13,
    fontWeight: '600',
  },
});
