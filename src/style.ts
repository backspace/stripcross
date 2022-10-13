const CLUES_SELECTOR = process.env.CLUES_SELECTOR!;

const css = `
html {
    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
  }
  
  h1 {
    display: inline-block;
    font-size: 1.5em;
    margin: 0;
  }
  
  h2 {
    display: inline-block;
    font-size: 1em;
    margin: 0 0 0 1rem;
  }
  
  @media print {
    a.break-cache, a.puzzle-toggle, a.clues-toggle, a.previous, a.next {
      display: none;
    }
  }
  
  a.break-cache, a.puzzle-toggle, a.clues-toggle {
    margin-right: 1rem;
  }

  a.previous + a.next {
    margin-left: 1rem;
  }
  
  .warning {
    background: pink;
    padding: 1em;
  }
  
  table {
    border-collapse: collapse;
    float: right;
  }
  
  td {
    position: relative;
    width: 22px;
    height: 22px;
  
    padding: 0;
  
    border: 1px solid black;
    vertical-align: top;
  
    font-size: 8px;
  }
  
  td.filled {
    background: repeating-linear-gradient(
      45deg,
      white,
      #888 2px,
      white 2px,
      #888 2px
    );
  }
  td.shaded {
    background: #d3d3d3;
  }
  
  td.circled *:first-child::after {
    content: '';
    position: absolute;
    border-radius: 22px;
    border: 1px solid black;
    width: 17px;
    height: 17px;
    top: 2px;
    left: 3px;
  }
  
  CLUES_SELECTOR {
    column-count: 3;
  }
  
  CLUES_SELECTOR div div:nth-child(2) {
    max-width: 15em;
  }
  
  CLUES_SELECTOR div div div {
    display: inline;
  }
  
  CLUES_SELECTOR div div div:nth-child(odd) {
    font-size: 9px;
    font-weight: bold;
    padding-right: 3px;
  }
  
  CLUES_SELECTOR div div div:nth-child(even) {
    font-size: 10px;
  }
  
  CLUES_SELECTOR div div div:nth-child(even)::after {
    content: '';
    display: block;
  }

  body.hide-puzzle table {
    display: none;
  }

  body.hide-puzzle CLUES_SELECTOR {
    column-count: 2;
  }

  body.hide-clues CLUES_SELECTOR {
    display: none;
  }

  body.hide-clues table {
    float: none;
  }
`;

export default function style() {
  return css.replace(/CLUES_SELECTOR/g, CLUES_SELECTOR);
}
