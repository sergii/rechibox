import { useRouter, useTheme } from 'expo-router';
import { type ComponentRef, useEffect, useRef, useState } from 'react';
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
  acceptWorldProposal,
  answerWorldClarification,
  askWorld,
  getWorldQueryConfiguration,
  rejectWorldProposal,
  WorldQueryClientError,
  type WorldMutationProposal,
  type WorldQueryAnswerStatus,
  type WorldQueryClarification,
  type WorldQueryClarificationOption,
} from '@/world-query/client';
import { bootstrapWorldSession, type WorldSession } from '@/world-query/session';

type PendingMutation = {
  proposal: WorldMutationProposal;
  subjectLabel: string;
  locationLabel: string;
};

type ChatMessage = {
  id: number;
  role: 'user' | 'assistant';
  text: string;
  status?: WorldQueryAnswerStatus;
  clarification?: WorldQueryClarification;
  mutation?: PendingMutation;
};

export default function HomeScreen() {
  const { colors } = useTheme();
  const router = useRouter();
  const scrollViewRef = useRef<ComponentRef<typeof ScrollView>>(null);
  const nextMessageId = useRef(1);
  const configuration = getWorldQueryConfiguration();
  const [draft, setDraft] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isSending, setIsSending] = useState(false);
  const [resolvingClarificationId, setResolvingClarificationId] = useState<string | null>(null);
  const [reviewingProposalId, setReviewingProposalId] = useState<string | null>(null);
  const [session, setSession] = useState<WorldSession | null>(null);
  const [isBootstrapping, setIsBootstrapping] = useState(configuration.ready);
  const [bootstrapError, setBootstrapError] = useState<string | null>(null);
  const [bootstrapAttempt, setBootstrapAttempt] = useState(0);

  useEffect(() => {
    if (!configuration.ready) return;

    let cancelled = false;

    void bootstrapWorldSession()
      .then((nextSession) => {
        if (!cancelled) setSession(nextSession);
      })
      .catch((error: unknown) => {
        if (!cancelled) {
          setSession(null);
          setBootstrapError(errorMessage(error));
        }
      })
      .finally(() => {
        if (!cancelled) setIsBootstrapping(false);
      });

    return () => {
      cancelled = true;
    };
  }, [bootstrapAttempt, configuration.apiUrl, configuration.ready]);

  const retryBootstrap = () => {
    setBootstrapError(null);
    setIsBootstrapping(true);
    setBootstrapAttempt((current) => current + 1);
  };

  const appendMessage = (message: Omit<ChatMessage, 'id'>) => {
    const id = nextMessageId.current;
    nextMessageId.current += 1;
    setMessages((current) => [...current, { id, ...message }]);
  };

  const submit = async () => {
    const message = draft.trim();
    if (!message || isSending || resolvingClarificationId || reviewingProposalId || !session) return;

    setDraft('');
    appendMessage({ role: 'user', text: message });
    setIsSending(true);

    try {
      const result = await askWorld(message, session.worldId);
      if (result.clarification) {
        appendMessage({
          role: 'assistant',
          text: result.clarification.question,
          status: 'ambiguous',
          clarification: result.clarification,
        });
      } else if (result.answer?.text) {
        appendMessage({
          role: 'assistant',
          text: result.answer.text,
          status: result.answer.status,
        });
      } else if (result.command?.status === 'ready_for_review' && result.command.proposal) {
        const subjectLabel = result.command.subjectLabel ?? 'цю річ';
        const locationLabel = result.command.locationLabel ?? 'це місце';
        appendMessage({
          role: 'assistant',
          text: `Записати, що «${subjectLabel}» тепер у «${locationLabel}»?`,
          mutation: { proposal: result.command.proposal, subjectLabel, locationLabel },
        });
      } else if (result.command?.status === 'already_current') {
        appendMessage({ role: 'assistant', text: 'Це вже записано у World State. Нічого змінювати не потрібно.' });
      } else if (result.command?.status === 'ambiguous') {
        appendMessage({
          role: 'assistant',
          text: 'Я бачу кілька схожих речей або місць. Уточніть назву, щоб я нічого не змінив помилково.',
          status: 'ambiguous',
        });
      } else if (result.command?.status === 'unresolved') {
        appendMessage({
          role: 'assistant',
          text: 'Я не знайшов одну з названих речей або місць у вашому World State. Нічого не змінено.',
          status: 'unknown',
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
          text: 'Я поки не розпізнав це як підтримуваний запит або явну зміну місця. Нічого не змінено.',
          status: 'unavailable',
        });
      }
    } catch (error) {
      appendMessage({ role: 'assistant', text: errorMessage(error), status: 'unavailable' });
    } finally {
      setIsSending(false);
    }
  };

  const resolveClarification = async (
    messageId: number,
    clarification: WorldQueryClarification,
    option: WorldQueryClarificationOption | null,
  ) => {
    if (!session || resolvingClarificationId || reviewingProposalId) return;

    setResolvingClarificationId(clarification.id);
    setMessages((current) =>
      current.map((message) =>
        message.id === messageId ? { ...message, clarification: undefined } : message,
      ),
    );
    appendMessage({ role: 'user', text: option?.label ?? 'Жоден із варіантів' });

    try {
      const result = await answerWorldClarification(
        session.worldId,
        clarification.id,
        option?.option_id ?? null,
      );
      if (result.answer?.text) {
        appendMessage({ role: 'assistant', text: result.answer.text, status: result.answer.status });
      } else {
        appendMessage({
          role: 'assistant',
          text: 'Не вдалося продовжити пошук після уточнення.',
          status: 'unavailable',
        });
      }
    } catch (error) {
      appendMessage({ role: 'assistant', text: errorMessage(error), status: 'unavailable' });
    } finally {
      setResolvingClarificationId(null);
    }
  };

  const reviewMutation = async (messageId: number, mutation: PendingMutation, accept: boolean) => {
    if (!session || reviewingProposalId || resolvingClarificationId) return;

    setReviewingProposalId(mutation.proposal.id);
    setMessages((current) =>
      current.map((message) => (message.id === messageId ? { ...message, mutation: undefined } : message)),
    );
    appendMessage({ role: 'user', text: accept ? 'Так, записати' : 'Ні, не змінювати' });

    try {
      const proposal = accept
        ? await acceptWorldProposal(session.worldId, mutation.proposal.id)
        : await rejectWorldProposal(session.worldId, mutation.proposal.id);

      if (accept && proposal.status === 'accepted') {
        appendMessage({
          role: 'assistant',
          text: `Готово. Записав: «${mutation.subjectLabel}» → «${mutation.locationLabel}».`,
        });
      } else if (!accept && proposal.status === 'rejected') {
        appendMessage({ role: 'assistant', text: 'Добре, World State не змінено.' });
      } else {
        appendMessage({
          role: 'assistant',
          text: 'Стан зміни вже не актуальний. Перевірте поточне місце речі ще раз.',
          status: 'conflict',
        });
      }
    } catch (error) {
      appendMessage({ role: 'assistant', text: errorMessage(error), status: 'unavailable' });
    } finally {
      setReviewingProposalId(null);
    }
  };

  const composerDisabled =
    isSending || Boolean(resolvingClarificationId) || Boolean(reviewingProposalId) || isBootstrapping || !session;
  const sendDisabled = composerDisabled || draft.trim().length === 0;

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
              <Text style={[styles.subtitle, { color: colors.text }]}>Запитайте про речі або скажіть, куди ви їх поклали.</Text>
              <View style={styles.examples}>
                {['Де мої кабелі?', 'Що в синій коробці?', 'Я поклав зарядки в синю коробку'].map((example) => (
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
                {message.clarification ? (
                  <View style={styles.clarificationOptions}>
                    {message.clarification.options.map((option) => (
                      <Pressable
                        accessibilityLabel={`Обрати ${option.label}`}
                        accessibilityRole="button"
                        disabled={Boolean(resolvingClarificationId) || Boolean(reviewingProposalId)}
                        key={option.option_id}
                        onPress={() => void resolveClarification(message.id, message.clarification!, option)}
                        style={({ pressed }) => [
                          styles.clarificationOption,
                          {
                            backgroundColor: colors.card,
                            borderColor: colors.border,
                            opacity: pressed ? 0.65 : 1,
                          },
                        ]}>
                        <Text style={[styles.clarificationOptionLabel, { color: colors.text }]}>{option.label}</Text>
                        <Text style={[styles.clarificationOptionKind, { color: colors.text }]}>{kindLabel(option.kind)}</Text>
                      </Pressable>
                    ))}
                    <Pressable
                      accessibilityLabel="Жоден із варіантів"
                      accessibilityRole="button"
                      disabled={Boolean(resolvingClarificationId) || Boolean(reviewingProposalId)}
                      onPress={() => void resolveClarification(message.id, message.clarification!, null)}
                      style={({ pressed }) => [styles.noneOption, { opacity: pressed ? 0.65 : 1 }]}>
                      <Text style={[styles.noneOptionText, { color: colors.primary }]}>Жоден із варіантів</Text>
                    </Pressable>
                  </View>
                ) : null}
                {message.mutation ? (
                  <View style={styles.mutationActions}>
                    <Pressable
                      accessibilityLabel="Підтвердити зміну місця"
                      accessibilityRole="button"
                      disabled={Boolean(reviewingProposalId)}
                      onPress={() => void reviewMutation(message.id, message.mutation!, true)}
                      style={({ pressed }) => [
                        styles.mutationPrimary,
                        { backgroundColor: colors.primary, opacity: pressed ? 0.65 : 1 },
                      ]}>
                      <Text style={styles.mutationPrimaryText}>Так, записати</Text>
                    </Pressable>
                    <Pressable
                      accessibilityLabel="Відхилити зміну місця"
                      accessibilityRole="button"
                      disabled={Boolean(reviewingProposalId)}
                      onPress={() => void reviewMutation(message.id, message.mutation!, false)}
                      style={({ pressed }) => [
                        styles.mutationSecondary,
                        { borderColor: colors.border, opacity: pressed ? 0.65 : 1 },
                      ]}>
                      <Text style={[styles.mutationSecondaryText, { color: colors.text }]}>Ні</Text>
                    </Pressable>
                  </View>
                ) : null}
              </View>
            ))
          )}
          {isSending || resolvingClarificationId || reviewingProposalId ? (
            <View style={[styles.loadingBubble, { backgroundColor: colors.card, borderColor: colors.border }]}>
              <ActivityIndicator color={colors.primary} size="small" />
              <Text accessibilityLiveRegion="polite" style={[styles.loadingText, { color: colors.text }]}> 
                {reviewingProposalId
                  ? 'Оновлюю World State…'
                  : resolvingClarificationId
                    ? 'Продовжую пошук…'
                    : 'Перевіряю World State…'}
              </Text>
            </View>
          ) : null}
        </ScrollView>

        <View style={[styles.composerArea, { borderTopColor: colors.border }]}>
          {!configuration.ready ? (
            <Text style={[styles.connectionNote, { color: colors.text }]}>Backend не підключено в цій збірці.</Text>
          ) : isBootstrapping ? (
            <View style={styles.connectionRow}>
              <ActivityIndicator color={colors.primary} size="small" />
              <Text style={[styles.connectionNote, { color: colors.text }]}>Підключаю ваш простір…</Text>
            </View>
          ) : bootstrapError ? (
            <View style={styles.connectionRow}>
              <Text style={[styles.connectionNote, { color: colors.text }]}>{bootstrapError}</Text>
              <Pressable
                accessibilityLabel="Повторити підключення"
                accessibilityRole="button"
                onPress={retryBootstrap}>
                <Text style={[styles.retryText, { color: colors.primary }]}>Повторити</Text>
              </Pressable>
            </View>
          ) : null}
          <View style={styles.composerRow}>
            <TextInput
              accessibilityLabel="Запит до Rechibox"
              editable={!composerDisabled}
              multiline
              onChangeText={setDraft}
              onSubmitEditing={() => void submit()}
              placeholder="Запитайте або скажіть, куди поклали річ"
              placeholderTextColor={colors.border}
              returnKeyType="send"
              style={[
                styles.input,
                { borderColor: colors.border, color: colors.text, backgroundColor: colors.card },
              ]}
              submitBehavior="submit"
              value={draft}
            />
            <Pressable
              accessibilityLabel="Надіслати запит"
              accessibilityRole="button"
              accessibilityState={{ disabled: sendDisabled }}
              disabled={sendDisabled}
              onPress={() => void submit()}
              style={({ pressed }) => [
                styles.sendButton,
                {
                  backgroundColor: colors.primary,
                  opacity: sendDisabled ? 0.35 : pressed ? 0.65 : 1,
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
    if (error.code === 'not_configured') return 'Пошук у ваших речах поки недоступний у цій збірці.';
    if (error.code === 'invalid_response') return 'Backend повернув неочікувану відповідь. Спробуйте ще раз пізніше.';
  }
  return 'Не вдалося зв’язатися з Rechibox. Перевірте підключення та спробуйте ще раз.';
}

function statusLabel(status: WorldQueryAnswerStatus) {
  switch (status) {
    case 'ambiguous': return 'Потрібне уточнення';
    case 'unknown': return 'Немає записаних даних';
    case 'conflict': return 'Конфлікт у даних';
    case 'unavailable': return 'Недоступно';
    default: return '';
  }
}

function kindLabel(kind: string) {
  switch (kind) {
    case 'container': return 'Контейнер';
    case 'item': return 'Річ';
    case 'space': return 'Місце';
    case 'furniture': return 'Меблі';
    case 'person': return 'Людина';
    default: return kind;
  }
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  keyboardAvoidingView: { flex: 1 },
  header: { minHeight: 58, paddingHorizontal: 18, paddingVertical: 10, borderBottomWidth: StyleSheet.hairlineWidth, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  logo: { width: 142, height: 34 },
  headerActions: { flexDirection: 'row', gap: 8 },
  headerButton: { minHeight: 40, justifyContent: 'center', paddingHorizontal: 12, borderWidth: 1, borderRadius: 20 },
  headerButtonText: { fontSize: 14, fontWeight: '600' },
  messages: { flex: 1 },
  messagesContent: { flexGrow: 1, paddingHorizontal: 18, paddingVertical: 20, gap: 12 },
  emptyState: { flex: 1, justifyContent: 'center', paddingVertical: 28, gap: 10 },
  title: { fontSize: 30, lineHeight: 36, fontWeight: '700' },
  subtitle: { fontSize: 17, lineHeight: 24, opacity: 0.7 },
  examples: { marginTop: 14, gap: 10 },
  example: { alignSelf: 'flex-start', minHeight: 44, justifyContent: 'center', paddingHorizontal: 14, paddingVertical: 10, borderWidth: 1, borderRadius: 22 },
  exampleText: { fontSize: 15 },
  messageRow: { width: '100%', gap: 8 },
  userMessageRow: { alignItems: 'flex-end' },
  assistantMessageRow: { alignItems: 'flex-start' },
  bubble: { maxWidth: '86%', borderRadius: 18, paddingHorizontal: 14, paddingVertical: 11 },
  messageText: { fontSize: 16, lineHeight: 22 },
  statusText: { marginTop: 7, fontSize: 12, fontWeight: '600', opacity: 0.55 },
  clarificationOptions: { width: '86%', gap: 7 },
  clarificationOption: { minHeight: 48, justifyContent: 'center', paddingHorizontal: 14, paddingVertical: 9, borderWidth: 1, borderRadius: 14 },
  clarificationOptionLabel: { fontSize: 15, lineHeight: 20, fontWeight: '600' },
  clarificationOptionKind: { marginTop: 2, fontSize: 12, opacity: 0.55 },
  noneOption: { minHeight: 40, justifyContent: 'center', paddingHorizontal: 8 },
  noneOptionText: { fontSize: 14, fontWeight: '600' },
  mutationActions: { width: '86%', flexDirection: 'row', gap: 8 },
  mutationPrimary: { minHeight: 44, flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 14, borderRadius: 14 },
  mutationPrimaryText: { color: '#FFFFFF', fontSize: 14, fontWeight: '700' },
  mutationSecondary: { minHeight: 44, minWidth: 72, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 14, borderWidth: 1, borderRadius: 14 },
  mutationSecondaryText: { fontSize: 14, fontWeight: '600' },
  loadingBubble: { alignSelf: 'flex-start', minHeight: 44, flexDirection: 'row', alignItems: 'center', gap: 9, paddingHorizontal: 14, borderRadius: 18, borderWidth: 1 },
  loadingText: { fontSize: 14, opacity: 0.7 },
  composerArea: { paddingHorizontal: 14, paddingTop: 10, paddingBottom: 8, borderTopWidth: StyleSheet.hairlineWidth, gap: 7 },
  connectionRow: { minHeight: 24, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8 },
  connectionNote: { fontSize: 12, textAlign: 'center', opacity: 0.55 },
  retryText: { fontSize: 12, fontWeight: '700' },
  composerRow: { flexDirection: 'row', alignItems: 'flex-end', gap: 8 },
  input: { flex: 1, minHeight: 48, maxHeight: 120, paddingHorizontal: 14, paddingTop: 12, paddingBottom: 12, borderWidth: 1, borderRadius: 20, fontSize: 16, lineHeight: 21 },
  sendButton: { width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center' },
  sendButtonText: { color: '#FFFFFF', fontSize: 26, lineHeight: 28, fontWeight: '700' },
  cameraLink: { minHeight: 32, textAlign: 'center', textAlignVertical: 'center', fontSize: 13, fontWeight: '600' },
});