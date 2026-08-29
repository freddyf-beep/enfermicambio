import { useRef, useState } from 'react'
import Icon from './Icon.jsx'
import { readableSocialText } from '../lib/display-text.js'

const POST_TYPES = {
  photo: { icon: 'camera', label: 'Foto', tone: 'violet' },
  meal: { icon: 'food', label: 'Comida', tone: 'coral' },
  workout: { icon: 'dumbbell', label: 'Entrenamiento', tone: 'lime' },
  route: { icon: 'route', label: 'Ruta', tone: 'blue' },
  steps: { icon: 'figureRun', label: 'Actividad', tone: 'lime' },
  achievement: { icon: 'medal', label: 'Logro', tone: 'violet' },
  mission: { icon: 'target', label: 'Misión', tone: 'coral' },
  ranking_change: { icon: 'chart', label: 'Ranking', tone: 'blue' },
  round_result: { icon: 'trophy', label: 'Resultado', tone: 'violet' },
  season: { icon: 'trophy', label: 'Temporada', tone: 'violet' },
}

const fallbackType = { icon: 'activity', label: 'Actualización', tone: 'lime' }

export default function SocialPost({ post, authorName, currentUserId, nameFor, ago, onReact, onComment, onError, highlighted = false }) {
  const [conversationOpen, setConversationOpen] = useState(false)
  const [comment, setComment] = useState('')
  const [sending, setSending] = useState(false)
  const [reacting, setReacting] = useState(false)
  const sendingRef = useRef(false)
  const reactingRef = useRef(false)
  const type = POST_TYPES[post.post_type] || fallbackType
  const comments = post.comments || []
  const reactions = post.reactions || []
  const reacted = reactions.some(reaction => reaction.user_id === currentUserId && reaction.emoji === '🔥')
  const previewComments = conversationOpen ? comments : comments.slice(-1)

  const react = async () => {
    if (reactingRef.current) return
    reactingRef.current = true
    setReacting(true)
    try { await onReact(post.id, '🔥') }
    catch (error) { onError(error.message) }
    finally { reactingRef.current = false; setReacting(false) }
  }

  const submit = async event => {
    event.preventDefault()
    const body = comment.trim()
    if (!body || sendingRef.current) return
    sendingRef.current = true
    setSending(true)
    try {
      await onComment(post.id, body, crypto.randomUUID())
      setComment('')
    } catch (error) { onError(error.message) }
    finally { sendingRef.current = false; setSending(false) }
  }

  return <article id={`post-${post.id}`} className={`ec-post-card${highlighted ? ' highlighted' : ''}`}>
    <header className="ec-post-head">
      <span className="ec-avatar ec-post-avatar">{authorName[0]}</span>
      <div>
        <b>{authorName}</b>
        <span><span className={`ec-post-type ${type.tone}`}><Icon name={type.icon} />{type.label}</span><small>· {ago(post.created_at)}</small></span>
      </div>
    </header>

    <p className="ec-post-caption">{readableSocialText(post.caption)}</p>

    {!!post.media?.length && <div className="ec-post-media">{post.media.map((item, index) => item.media_type === 'video'
      ? <video key={index} src={item.resolved_url} controls preload="metadata" />
      : <img key={index} src={item.resolved_url} alt={`Publicación de ${authorName}`} loading="lazy" />)}</div>}

    {(reactions.length > 0 || comments.length > 0) && <div className="ec-post-summary">
      <span>{reactions.length > 0 ? <><i><Icon name="flame" /></i>{reactions.length} {reactions.length === 1 ? 'motivación' : 'motivaciones'}</> : ''}</span>
      {comments.length > 0 && <button onClick={() => setConversationOpen(value => !value)}>{comments.length} {comments.length === 1 ? 'comentario' : 'comentarios'}</button>}
    </div>}

    <div className="ec-post-actions">
      <button className={reacted ? 'on' : ''} aria-pressed={reacted} disabled={reacting} onClick={react}><Icon name="flame" />{reacted ? 'Motivado' : 'Motivar'}</button>
      <button aria-expanded={conversationOpen} onClick={() => setConversationOpen(value => !value)}><Icon name="people" />Comentar</button>
    </div>

    {previewComments.length > 0 && <div className="ec-post-comments">
      {!conversationOpen && comments.length > 1 && <button onClick={() => setConversationOpen(true)}>Ver los {comments.length} comentarios</button>}
      {previewComments.map(item => <p key={item.id}><b>{nameFor(item.author_id)}</b><span>{readableSocialText(item.body)}</span></p>)}
    </div>}

    {conversationOpen && <form className="ec-comment" onSubmit={submit}>
      <span className="ec-avatar">{nameFor(currentUserId)[0]}</span>
      <input aria-label={`Comentar la publicación de ${authorName}`} placeholder="Escribe un comentario…" value={comment} onChange={event => setComment(event.target.value)} />
      <button aria-label="Enviar comentario" disabled={!comment.trim() || sending}>{sending ? 'Enviando…' : 'Enviar'}</button>
    </form>}
  </article>
}
