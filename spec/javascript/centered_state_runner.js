(async () => {
  const failures = [];
  const sizes = [[1440, 1000], [960, 1000], [640, 1000], [390, 1000],
    [1440, 200], [390, 200], [1440, 120], [390, 120]];
  for (const [width, height] of sizes) {
    const frame = document.createElement('iframe');
    frame.width = width;
    frame.height = height;
    frame.srcdoc = page;
    const loaded = new Promise(resolve => frame.addEventListener('load', resolve, { once: true }));
    document.body.append(frame);
    await loaded;
    const doc = frame.contentDocument;
    await doc.fonts.ready;
    const state = doc.querySelector('.empty-state');
    const main = doc.querySelector('main');
    const box = state.getBoundingClientRect();
    const container = main.getBoundingClientRect();
    const heading = state.querySelector('h1').getBoundingClientRect();
    const finalText = state.lastElementChild.getBoundingClientRect();
    const check = (ok, reason) => { if (!ok) failures.push(`${width}x${height}: ${reason}`); };
    check(Math.abs(box.left + box.width / 2 - container.left - container.width / 2) < 2,
      'content is not centered horizontally');
    if (height === 1000) {
      check(Math.abs(box.top + box.height / 2 - container.top - container.height / 2) < 2,
        'content is not centered vertically');
    }
    check(heading.top >= 0 && box.top >= container.top, 'beginning is clipped above the scroll origin');
    check(doc.documentElement.scrollWidth <= width, 'long path forces document horizontal overflow');
    check(getComputedStyle(state).textAlign === 'left', 'prose alignment changed');
    frame.contentWindow.scrollTo(0, doc.documentElement.scrollHeight);
    const end = state.lastElementChild.getBoundingClientRect();
    check(end.bottom <= height + 2, 'last diagnostic cannot be reached by scrolling');
    check(finalText.height > 0, 'diagnostic text is missing');
    frame.remove();
  }
  document.querySelector('#result').textContent = JSON.stringify({ cases: sizes.length, failures });
})();
