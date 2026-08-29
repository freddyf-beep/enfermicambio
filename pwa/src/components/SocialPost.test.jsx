// @vitest-environment happy-dom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import SocialPost from './SocialPost.jsx'

describe('SocialPost', () => {
  let root

  beforeEach(() => {
    globalThis.IS_REACT_ACT_ENVIRONMENT = true
    document.body.innerHTML = '<div id="root"></div>'
  })

  afterEach(() => {
    act(() => root?.unmount())
  })

  it('blocks repeated comment submissions while the first request is pending', async () => {
    let finish
    const pending = new Promise(resolve => { finish = resolve })
    const onComment = vi.fn(() => pending)
    root = createRoot(document.getElementById('root'))
    await act(async () => {
      root.render(<SocialPost
        post={{ id: 'post-1', author_id: 'user-2', post_type: 'steps', caption: 'Meta lista', created_at: new Date().toISOString(), reactions: [], comments: [] }}
        authorName="Felipe"
        currentUserId="user-1"
        nameFor={id => id === 'user-1' ? 'Freddy' : 'Felipe'}
        ago={() => 'ahora'}
        onReact={vi.fn()}
        onComment={onComment}
        onError={vi.fn()}
      />)
    })

    await act(async () => {
      document.querySelector('.ec-post-actions button:last-child').click()
    })
    const input = document.querySelector('.ec-comment input')
    await act(async () => {
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(input, 'Vamos con todo')
      input.dispatchEvent(new Event('input', { bubbles: true }))
    })
    const form = document.querySelector('.ec-comment')
    await act(async () => {
      form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
      form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
      await Promise.resolve()
    })

    expect(onComment).toHaveBeenCalledTimes(1)
    expect(onComment).toHaveBeenCalledWith('post-1', 'Vamos con todo', expect.any(String))

    await act(async () => { finish() })
  })
})
