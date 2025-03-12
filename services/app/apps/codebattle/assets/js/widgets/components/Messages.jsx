import React, { useRef, useLayoutEffect, useState } from 'react';

import cn from 'classnames';
// import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';

import useStayScrolled from '../utils/useStayScrolled';

import Message from './Message';

const getKey = (id, time, name, index) => {
  if (!time || !name) {
    return id;
  }

  return `${id}-${time}-${name}-${index}`;
};

function Messages({ messages, displayMenu = () => {}, disabled = false }) {
  const listRef = useRef();
  const minScrollHeight = 20;
  const [scrollHeight, setScrollHeight] = useState(0);
  const [isScrollButtonVisible, setIsScrollButtonVisible] = useState(false);
  const { stayScrolled, scrollBottom } = useStayScrolled(listRef);
  // Typically you will want to use stayScrolled or scrollBottom inside
  // useLayoutEffect, because it measures and changes DOM attributes (scrollTop) directly
  useLayoutEffect(() => {
    if (scrollHeight > minScrollHeight) {
      stayScrolled();
      setIsScrollButtonVisible(true);
    } else {
      scrollBottom();
      setIsScrollButtonVisible(false);
    }
  }, [messages.length, stayScrolled, scrollBottom]);

  const scrollHandler = e => {
    const chatContainer = e.target;
    const chatScrollHeight = chatContainer.scrollHeight - chatContainer.scrollTop - chatContainer.clientHeight;

    if (chatScrollHeight < minScrollHeight) {
      setIsScrollButtonVisible(false);
    }

    setScrollHeight(chatScrollHeight);
  };

  const scrollButtonClass = cn('scroll-button', 'position-absolute', 'rounded-circle', 'bg-secondary', 'p-0', 'border-0', {
    invisible: !isScrollButtonVisible,
  });

  if (disabled) {
    return (
      <div title="Chat is disabled" className="h-100 position-relative" ref={listRef}>
        {/* <span className="d-flex text-muted position-absolute h-100 w-100 justify-content-center align-items-center"> */}
        {/*   <FontAwesomeIcon className="h-25 w-25" icon="comment-slash" /> */}
        {/* </span> */}
        {/* <div className="position-absolute h-100 w-100 bg-dark cb-opacity-50 rounded-left" /> */}
      </div>
    );
  }

  return (
    <>
      <ul
        ref={listRef}
        className="overflow-auto pt-0 pl-3 pr-2 position-relative cb-messages-list flex-grow-1"
        onScroll={scrollHandler}
      >
        {messages.map((message, index) => {
          const {
            id, userId, name, text, type, time, meta,
          } = message;

          const key = getKey(id, time, name, messages.length - index);

          return (
            <Message
              name={name}
              userId={userId}
              text={text}
              key={key}
              type={type}
              time={time}
              meta={meta}
              displayMenu={displayMenu}
            />
          );
        })}
      </ul>
      <button
        type="button"
        className={scrollButtonClass}
        onClick={scrollBottom}
        aria-label="Scroll to bottom"
      />
    </>
  );
}

export default Messages;
