// MarkdownCopyScript.swift
// JavaScript injected into MarkdownWebView: copying a selection puts Markdown on the clipboard.

enum MarkdownCopyScript {
    // ponytail: the Markdown is rebuilt from the rendered selection, so it is equivalent to the
    // source but not byte-identical: bullets become "-", a partly selected numbered list is
    // numbered from the start of the list, a table selected without its header uses the first selected
    // row as the header, and literal * or _ are not re-escaped. Map the selection to source
    // positions (CMARK_OPT_SOURCEPOS) if exact source text is ever needed.
    static let source = #"""
        (() => {
            const BLOCK_TAGS = new Set([
                'P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'PRE', 'BLOCKQUOTE', 'UL', 'OL', 'TABLE', 'HR',
            ]);
            // A selection inside these loses the element itself, which carries the structure.
            const STRUCTURE_TAGS = new Set(['UL', 'OL', 'TABLE', 'THEAD', 'TBODY', 'TR']);
            const TABLE_ALIGNMENTS = { left: ':---', right: '---:', center: ':---:' };
            const MIN_FENCE_LENGTH = 3;

            const wrap = (marker, text) => (text ? marker + text + marker : '');
            const indentFollowingLines = (text, indent) => text.replace(/\n(?=.)/g, '\n' + indent);

            const inline = (parent) => Array.from(parent.childNodes).map(inlineNode).join('');

            function inlineNode(node) {
                if (node.nodeType === Node.TEXT_NODE) return node.textContent;
                if (node.nodeType !== Node.ELEMENT_NODE) return '';
                switch (node.tagName) {
                    case 'STRONG': return wrap('**', inline(node));
                    case 'EM': return wrap('*', inline(node));
                    case 'DEL': return wrap('~~', inline(node));
                    case 'CODE': return wrap('`', node.textContent);
                    case 'A': return link(node);
                    case 'IMG': return `![${node.alt}](${node.getAttribute('src')})`;
                    case 'BR': return '  \n';
                    case 'INPUT': return node.checked ? '[x]' : '[ ]';
                    default: return inline(node);
                }
            }

            function link(node) {
                const text = inline(node);
                const href = node.getAttribute('href');
                return text === href ? href : `[${text}](${href})`;
            }

            // Markdown of each block in the parent; inline nodes next to each other form one block.
            function blocks(parent) {
                const result = [];
                let inlineRun = '';
                const flushInlineRun = () => {
                    const text = inlineRun.replace(/^\n+|\s+$/g, '');
                    if (text) result.push(text);
                    inlineRun = '';
                };
                for (const node of parent.childNodes) {
                    if (BLOCK_TAGS.has(node.tagName)) {
                        flushInlineRun();
                        result.push(block(node));
                    } else {
                        inlineRun += inlineNode(node);
                    }
                }
                flushInlineRun();
                return result;
            }

            function block(node) {
                switch (node.tagName) {
                    case 'P': return inline(node);
                    case 'PRE': return codeBlock(node);
                    case 'BLOCKQUOTE': return blocks(node).join('\n\n').replace(/^/gm, '> ');
                    case 'UL':
                    case 'OL': return list(node);
                    case 'TABLE': return table(node);
                    case 'HR': return '---';
                    default: return '#'.repeat(Number(node.tagName[1])) + ' ' + inline(node);
                }
            }

            function codeBlock(node) {
                const code = node.textContent.replace(/\n$/, '');
                const language = node.querySelector('code')?.className.match(/language-(\S+)/)?.[1] ?? '';
                const backtickRuns = code.match(/`+/g) ?? [];
                const longestRun = Math.max(0, ...backtickRuns.map((run) => run.length));
                const fence = '`'.repeat(Math.max(MIN_FENCE_LENGTH, longestRun + 1));
                return `${fence}${language}\n${code}\n${fence}`;
            }

            function list(node) {
                const items = Array.from(node.children);
                // cmark wraps item text in <p> only in a loose list (items separated by blank lines).
                const separator = node.querySelector(':scope > li > p') ? '\n\n' : '\n';
                let number = Number(node.getAttribute('start') ?? 1);
                return items.map((item) => {
                    const marker = node.tagName === 'OL' ? `${number++}. ` : '- ';
                    const content = blocks(item).join(separator);
                    return marker + indentFollowingLines(content, ' '.repeat(marker.length));
                }).join(separator);
            }

            function table(node) {
                const rows = Array.from(node.querySelectorAll('tr'), (row) => Array.from(row.children));
                if (rows.length === 0) return '';
                const line = (cells) => `| ${cells.join(' | ')} |`;
                const cellText = (cell) => inline(cell).trim().replace(/\n/g, ' ').replace(/\|/g, '\\|');
                const alignments = rows[0].map((cell) => TABLE_ALIGNMENTS[cell.getAttribute('align')] ?? '---');
                const [header, ...body] = rows.map((cells) => line(cells.map(cellText)));
                return [header, line(alignments), ...body].join('\n');
            }

            // The copied fragment starts below the common ancestor of the selection, so a selection
            // of several list items or table rows is put back into copies of the list or table.
            function selectedFragment(range) {
                let content = range.cloneContents();
                let ancestor = range.commonAncestorContainer;
                while (ancestor && STRUCTURE_TAGS.has(ancestor.tagName)) {
                    const shell = ancestor.cloneNode(false);
                    shell.append(content);
                    content = document.createDocumentFragment();
                    content.append(shell);
                    ancestor = ancestor.parentNode;
                }
                return content;
            }

            document.addEventListener('copy', (event) => {
                const selection = window.getSelection();
                if (selection.isCollapsed || selection.rangeCount === 0) return;
                const markdown = blocks(selectedFragment(selection.getRangeAt(0))).join('\n\n');
                event.clipboardData.setData('text/plain', markdown);
                event.preventDefault();
            });
        })();
        """#
}
