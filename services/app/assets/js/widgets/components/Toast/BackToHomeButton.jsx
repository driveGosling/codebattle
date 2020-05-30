import React from 'react';

export default function BackToHomeButton() {
  const handleClick = () => {
    window.location.href = '/';
  };

  return (
    <button className="btn btn-secondary btn-block" onClick={handleClick} type="button">
      Back to home
    </button>
  );
}
