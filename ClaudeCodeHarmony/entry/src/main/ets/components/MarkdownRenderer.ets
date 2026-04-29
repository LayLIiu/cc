/**
 * Markdown 渲染器
 * 完全还原 iOS 端 MarkdownRenderer
 */

// Markdown 节点类型
enum MarkdownNodeType {
  CodeBlock,
  Heading,
  UnorderedListItem,
  OrderedListItem,
  Blockquote,
  Paragraph,
  Spacer
}

// Markdown 节点
interface MarkdownNode {
  type: MarkdownNodeType;
  language?: string;
  code?: string;
  level?: number;
  text?: string;
  index?: number;
}

// Markdown 解析器
class MarkdownParser {
  static parse(content: string): MarkdownNode[] {
    const nodes: MarkdownNode[] = [];
    const lines = content.split('\n');
    let i = 0;

    while (i < lines.length) {
      const line = lines[i];

      // 代码块
      if (line.startsWith('```')) {
        const language = line.substring(3).trim();
        const codeLines: string[] = [];
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) {
          codeLines.push(lines[i]);
          i++;
        }
        nodes.push({
          type: MarkdownNodeType.CodeBlock,
          language: language,
          code: codeLines.join('\n')
        });
        i++;
        continue;
      }

      // 标题
      if (line.startsWith('#')) {
        let level = 0;
        for (let j = 0; j < line.length && line[j] === '#'; j++) {
          level++;
        }
        if (level >= 1 && level <= 6) {
          const text = line.substring(level).trim();
          nodes.push({ type: MarkdownNodeType.Heading, level: level, text: text });
          i++;
          continue;
        }
      }

      // 引用块
      if (line.startsWith('> ')) {
        const text = line.substring(2).trim();
        nodes.push({ type: MarkdownNodeType.Blockquote, text: text });
        i++;
        continue;
      }

      // 无序列表
      const trimmedLine = line.trim();
      if (trimmedLine.startsWith('- ') || trimmedLine.startsWith('* ') || trimmedLine.startsWith('+ ')) {
        const text = trimmedLine.substring(2).trim();
        nodes.push({ type: MarkdownNodeType.UnorderedListItem, text: text });
        i++;
        continue;
      }

      // 有序列表
      const orderedMatch = trimmedLine.match(/^(\d+)\.\s/);
      if (orderedMatch) {
        const index = parseInt(orderedMatch[1]);
        const text = trimmedLine.substring(orderedMatch[0].length).trim();
        nodes.push({ type: MarkdownNodeType.OrderedListItem, index: index, text: text });
        i++;
        continue;
      }

      // 空行
      if (trimmedLine === '') {
        nodes.push({ type: MarkdownNodeType.Spacer });
        i++;
        continue;
      }

      // 普通段落
      nodes.push({ type: MarkdownNodeType.Paragraph, text: line });
      i++;
    }

    return nodes;
  }
}

// 代码块视图组件
@Component
struct CodeBlockView {
  @Prop language: string = '';
  @Prop code: string = '';
  @State private showCopied: boolean = false;

  build() {
    Column() {
      // Header
      Row() {
        Text(this.language.length > 0 ? this.language.toLowerCase() : 'code')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255, 255, 255, 0.6)')
          .fontFamily('monospace')

        Blank()

        Button() {
          if (this.showCopied) {
            Text('已复制')
              .fontSize(11)
              .fontColor('#34C759')
          } else {
            Text('📋')
              .fontSize(11)
          }
        }
        .height(24)
        .backgroundColor('transparent')
        .onClick(() => {
          this.showCopied = true;
          setTimeout(() => {
            this.showCopied = false;
          }, 2000);
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })

      // 代码内容
      Scroll() {
        Text(this.code)
          .fontSize(13)
          .fontColor('rgba(255, 255, 255, 0.9)')
          .fontFamily('monospace')
          .width('100%')
          .padding(12)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('rgba(30, 30, 30, 1)')
    .borderRadius(8)
  }
}

// 内联文本渲染
@Component
struct InlineText {
  @Prop text: string = '';

  build() {
    Text(this.renderText())
      .fontSize(15)
      .fontColor('#1A1A1A')
  }

  private renderText(): string {
    let result = this.text;
    // 处理行内代码 - 简化显示
    result = result.replace(/`([^`]+)`/g, '[$1]');
    // 处理粗体
    result = result.replace(/\*\*([^*]+)\*\*/g, '$1');
    // 处理斜体
    result = result.replace(/\*([^*]+)\*/g, '$1');
    return result;
  }
}

// Markdown 渲染器主组件
@Component
export struct MarkdownRenderer {
  @Prop content: string = '';
  @State private nodes: MarkdownNode[] = [];

  aboutToAppear() {
    this.nodes = MarkdownParser.parse(this.content);
  }

  build() {
    Column() {
      ForEach(this.nodes, (node: MarkdownNode, index: number) => {
        this.renderNode(node);
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  renderNode(node: MarkdownNode) {
    if (node.type === MarkdownNodeType.CodeBlock) {
      CodeBlockView({
        language: node.language || '',
        code: node.code || ''
      })
    } else if (node.type === MarkdownNodeType.Heading) {
      Text(node.text || '')
        .fontSize(node.level ? 24 - node.level * 2 : 18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ top: node.level === 1 ? 8 : 4 })
    } else if (node.type === MarkdownNodeType.UnorderedListItem) {
      Row() {
        Text('• ')
          .fontSize(15)
          .fontColor('#6366F1')
        Text(this.renderInlineText(node.text || ''))
          .fontSize(15)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: 8 })
    } else if (node.type === MarkdownNodeType.OrderedListItem) {
      Row() {
        Text(`${node.index}. `)
          .fontSize(15)
          .fontColor('#6B6B6B')
          .width(24)
          .textAlign(TextAlign.End)
        Text(this.renderInlineText(node.text || ''))
          .fontSize(15)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: 8 })
    } else if (node.type === MarkdownNodeType.Blockquote) {
      Row() {
        Column() {}
          .width(3)
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.2)')
          .borderRadius(2)

        Text(node.text || '')
          .fontSize(15)
          .fontColor('#6B6B6B')
          .fontStyle(FontStyle.Italic)
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 4 })
    } else if (node.type === MarkdownNodeType.Paragraph) {
      this.ParagraphWithInline(node.text || '')
    } else if (node.type === MarkdownNodeType.Spacer) {
      Column() {}
        .width(1)
        .height(4)
    }
  }

  // 带内联格式的段落
  @Builder
  ParagraphWithInline(text: string) {
    Text(this.renderInlineText(text))
      .fontSize(15)
      .fontColor('#1A1A1A')
  }

  // 渲染内联文本
  private renderInlineText(text: string): string {
    let result = text;
    // 简化处理：移除格式标记但保留内容
    result = result.replace(/`([^`]+)`/g, '[$1]');
    result = result.replace(/\*\*([^*]+)\*\*/g, '$1');
    result = result.replace(/\*([^*]+)\*/g, '$1');
    return result;
  }
}
