/**
 * 主页面
 * 完全还原 iOS 端 UI - 磨砂玻璃 Tab 栏
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'MainPage';

// 模拟会话数据
interface SessionData {
  id: string;
  title: string;
  projectPath: string;
  status?: string;
  mascotColor: string;
}

// 分组会话接口
interface GroupedSession {
  title: string;
  sessions: SessionData[];
}

// 设置项接口
interface SettingsItem {
  label: string;
  value: string;
  showArrow: boolean;
}

@Entry
@Component
struct MainPage {
  @State currentTab: string = 'sessions';
  @State searchText: string = '';

  // 模拟会话数据 - 更丰富的测试数据
  private sessions: SessionData[] = [
    { id: '1', title: 'React 项目开发', projectPath: '/Users/dev/my-react-app', status: '已完成', mascotColor: '#E86B4A' },
    { id: '2', title: 'API 接口调试', projectPath: '/Users/dev/api-server', status: '工作中', mascotColor: '#2ECC71' },
    { id: '3', title: '移动端适配', projectPath: '/Users/dev/mobile-app', mascotColor: '#9B59B6' },
    { id: '4', title: '数据库优化', projectPath: '/Users/dev/db-project', status: '思考中', mascotColor: '#F39C12' },
  ];

  // 分组后的会话
  private get groupedSessions(): GroupedSession[] {
    return [
      { title: '今天', sessions: this.sessions },
      { title: '昨天', sessions: [] },
      { title: '更早', sessions: [] }
    ];
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 内容区域
      Column() {
        if (this.currentTab === 'sessions') {
          this.SessionsPage()
        } else if (this.currentTab === 'settings') {
          this.SettingsPage()
        } else {
          this.ProvidersPage()
        }
      }
      .width('100%')
      .height('100%')

      // Tab 栏 - 磨砂玻璃胶囊样式
      this.TabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }

  // Tab 栏 - 磨砂玻璃胶囊样式
  @Builder
  TabBar() {
    Row() {
      this.TabItem('会话', 'sessions')
      this.TabItem('设置', 'settings')
      this.TabItem('服务商', 'providers')
    }
    .width('100%')
    .height(50)
    .margin({ left: 16, right: 16, bottom: 8 })
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor('rgba(255, 255, 255, 0.85)')
    .backdropBlur(20)
    .borderRadius(28)
    .border({ width: 0.5, color: 'rgba(0, 0, 0, 0.1)' })
  }

  // Tab 项 - 胶囊滑块样式
  @Builder
  TabItem(label: string, id: string) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor(this.currentTab === id ? Color.White : '#6B6B6B')
        .fontWeight(this.currentTab === id ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .borderRadius(22)
    .backgroundColor(this.currentTab === id ? '#6366F1' : 'transparent')
    .onClick(() => {
      this.currentTab = id;
    })
    .layoutWeight(1)
  }

  // ==================== 会话列表页面 ====================

  @Builder
  SessionsPage() {
    Column() {
      // 标题栏
      Row() {
        Text('Claude Code')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 右上角 + 按钮
        Button() {
          Text('+')
            .fontSize(24)
            .fontColor('#6366F1')
        }
        .width(36)
        .height(36)
        .backgroundColor('transparent')
        .position({ x: '100%', y: 0 })
        .translate({ x: -36 })
      }
      .width('100%')
      .padding({ left: 16, right: 52, top: 60, bottom: 8 })

      // 搜索框
      Row() {
        Text('🔍 ')
          .fontSize(16)
        TextInput({ placeholder: '搜索对话...', text: this.searchText })
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .backgroundColor('transparent')
          .placeholderColor('#9A9A9A')
          .onChange((value: string) => {
            this.searchText = value;
          })

        if (this.searchText.length > 0) {
          Button() {
            Text('✕')
              .fontSize(14)
              .fontColor('#6B6B6B')
          }
          .width(24)
          .height(24)
          .backgroundColor('transparent')
          .onClick(() => {
            this.searchText = '';
          })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12 })
      .height(44)
      .backgroundColor('rgba(0, 0, 0, 0.05)')
      .borderRadius(12)
      .margin({ left: 16, right: 16, bottom: 8 })

      // 会话列表
      List() {
        ForEach(this.groupedSessions, (group: GroupedSession) => {
          ListItemGroup() {
            // Header
            this.GroupHeader(group.title, group.sessions.length)
            
            if (group.sessions.length > 0) {
              ForEach(group.sessions, (session: SessionData) => {
                ListItem() {
                  this.SessionCard(session)
                }
                .margin({ bottom: 8 })
              })
            }
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  // 分组标题
  @Builder
  GroupHeader(title: string, count: number) {
    Text(title)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor('#6B6B6B')
      .width('100%')
      .margin({ top: 8, bottom: 8, left: 4 })
  }

  // 会话卡片
  @Builder
  SessionCard(session: SessionData) {
    Row() {
      // 左边：像素吉祥物
      Stack() {
        // 身体
        Column() {}
          .width(24)
          .height(28)
          .backgroundColor(session.mascotColor)
          .borderRadius(4)
          .margin({ top: 4 })

        // 眼睛
        Row() {
          Column() {}
            .width(4)
            .height(4)
            .backgroundColor('#FFFFFF')
            .borderRadius(2)

          Column() {}
            .width(4)
            .height(4)
            .backgroundColor('#FFFFFF')
            .borderRadius(2)
            .margin({ left: 4 })
        }
        .margin({ top: 10 })
      }
      .width(32)
      .height(32)

      // 中间：标题和路径
      Column() {
        Text(session.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (session.projectPath) {
          Text(session.projectPath)
            .fontSize(13)
            .fontColor('#6B6B6B')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      // 右边：状态标签
      if (session.status) {
        Text(session.status)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(session.status))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.statusColor(session.status) + '15')
          .borderRadius(6)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('rgba(255, 255, 255, 0.9)')
    .backdropBlur(20)
    .borderRadius(18)
    .border({ width: 0.5, color: 'rgba(0, 0, 0, 0.08)' })
    .onClick(() => {
      // 跳转到聊天页面
      router.pushUrl({
        url: 'pages/ChatPage',
        params: {
          sessionId: session.id,
          title: session.title
        }
      });
    })
  }

  private statusColor(status: string): string {
    switch (status) {
      case '思考中':
      case '工作中':
      case '执行中':
        return '#34C759';
      case '等待权限':
      case '等待回答':
        return '#FF9500';
      case '已完成':
        return '#34C759';
      default:
        return '#6B6B6B';
    }
  }

  // ==================== 设置页面 ====================

  @Builder
  SettingsPage() {
    Column() {
      Scroll() {
        Column() {
          // 标题
          Text('设置')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 60, bottom: 24 })

          // 账户
          this.SettingsSection('账户', [
            { label: '用户', value: '未登录', showArrow: false } as SettingsItem
          ])

          // 连接设置
          this.ConnectionSection()

          // 外观
          this.SettingsSection('外观', [
            { label: '主题', value: '浅色', showArrow: true } as SettingsItem
          ])

          // 数据管理
          this.DataManagementSection()

          // 关于
          this.SettingsSection('关于', [
            { label: '版本', value: '1.0.0', showArrow: false } as SettingsItem,
            { label: '构建时间', value: '2026-04-26', showArrow: false } as SettingsItem,
            { label: '更新日志', value: '', showArrow: true } as SettingsItem
          ])

          // 退出登录
          Button('退出登录')
            .width('100%')
            .height(50)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#FF3B30')
            .borderRadius(12)
            .margin({ top: 24 })
            .onClick(() => {
              router.replaceUrl({ url: 'pages/Index' });
            })

          // 底部信息
          Text('Claude Code Harmony v1.0.0 (2026-04-26)')
            .fontSize(12)
            .fontColor('#6B6B6B')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 32, bottom: 100 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SettingsSection(title: string, items: SettingsItem[]) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#6B6B6B')
        .width('100%')
        .margin({ left: 4, bottom: 8 })

      Column() {
        ForEach(items, (item: SettingsItem, index: number) => {
          Row() {
            Text(item.label)
              .fontSize(16)
              .fontColor('#1A1A1A')

            Blank()

            if (item.value) {
              Text(item.value)
                .fontSize(16)
                .fontColor('#6B6B6B')
            }

            if (item.showArrow) {
              Text('›')
                .fontSize(16)
                .fontColor('#C7C7CC')
                .margin({ left: 4 })
            }
          }
          .width('100%')
          .height(44)
          .padding({ left: 12, right: 12 })

          if (index < items.length - 1) {
            Divider()
              .color('#E5E5EA')
              .margin({ left: 12 })
          }
        })
      }
      .width('100%')
      .backgroundColor('rgba(255, 255, 255, 0.9)')
      .backdropBlur(20)
      .borderRadius(12)
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  @Builder
  ConnectionSection() {
    Column() {
      Text('连接')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#6B6B6B')
        .width('100%')
        .margin({ left: 4, bottom: 8 })

      Column() {
        // 网络模式切换
        Row() {
          Text('当前网络')
            .fontSize(16)
            .fontColor('#1A1A1A')

          Blank()

          // 网络模式滑块
          Row() {
            this.NetworkTab('局域网', true, true)
            this.NetworkTab('公网', false, false)
          }
          .height(32)
          .padding(3)
          .backgroundColor('rgba(0, 0, 0, 0.08)')
          .borderRadius(10)
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })

        Divider().color('#E5E5EA').margin({ left: 12 })

        // 局域网地址
        Row() {
          Column() {
            Text('局域网地址')
              .fontSize(16)
              .fontColor('#1A1A1A')
            Text('未设置')
              .fontSize(13)
              .fontColor('#6B6B6B')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('编辑')
            .fontSize(14)
            .fontColor('#6366F1')
        }
        .width('100%')
        .height(52)
        .padding({ left: 12, right: 12 })

        Divider().color('#E5E5EA').margin({ left: 12 })

        // 公网地址
        Row() {
          Column() {
            Text('公网地址')
              .fontSize(16)
              .fontColor('#1A1A1A')
            Text('未设置')
              .fontSize(13)
              .fontColor('#6B6B6B')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('编辑')
            .fontSize(14)
            .fontColor('#6366F1')
        }
        .width('100%')
        .height(52)
        .padding({ left: 12, right: 12 })

        Divider().color('#E5E5EA').margin({ left: 12 })

        // 连接速度
        Row() {
          Text('连接速度')
            .fontSize(16)
            .fontColor('#1A1A1A')

          Blank()

          Text('点击测试')
            .fontSize(14)
            .fontColor('#6B6B6B')
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
      }
      .width('100%')
      .backgroundColor('rgba(255, 255, 255, 0.9)')
      .backdropBlur(20)
      .borderRadius(12)

      Text('局域网适合在家使用，公网适合外出使用')
        .fontSize(13)
        .fontColor('#6B6B6B')
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  @Builder
  NetworkTab(label: string, isActive: boolean, enabled: boolean) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(enabled ? (isActive ? Color.White : '#1A1A1A') : '#6B6B6B80')
      .width(50)
      .height(26)
      .textAlign(TextAlign.Center)
      .borderRadius(8)
      .backgroundColor(isActive && enabled ? '#6366F1' : 'transparent')
  }

  @Builder
  DataManagementSection() {
    Column() {
      Text('数据管理')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#6B6B6B')
        .width('100%')
        .margin({ left: 4, bottom: 8 })

      // 导入对话
      Row() {
        Text('📥')
          .fontSize(22)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#6366F115')
          .borderRadius(8)

        Column() {
          Text('导入对话')
            .fontSize(16)
            .fontColor('#1A1A1A')
          Text('从 Cloud Code 导入对话到本地')
            .fontSize(13)
            .fontColor('#6B6B6B')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        Text('›')
          .fontSize(16)
          .fontColor('#C7C7CC')
      }
      .width('100%')
      .height(60)
      .padding({ left: 12, right: 12 })
      .backgroundColor('rgba(255, 255, 255, 0.9)')
      .backdropBlur(20)
      .borderRadius(12)
      .margin({ bottom: 8 })

      // 存储管理
      Row() {
        Text('💾')
          .fontSize(22)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#FF950015')
          .borderRadius(8)

        Column() {
          Text('存储管理')
            .fontSize(16)
            .fontColor('#1A1A1A')
          Text('查看本地存储使用情况')
            .fontSize(13)
            .fontColor('#6B6B6B')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        Text('›')
          .fontSize(16)
          .fontColor('#C7C7CC')
      }
      .width('100%')
      .height(60)
      .padding({ left: 12, right: 12 })
      .backgroundColor('rgba(255, 255, 255, 0.9)')
      .backdropBlur(20)
      .borderRadius(12)
      .margin({ bottom: 8 })

      // 清除缓存
      Row() {
        Text('🗑️')
          .fontSize(22)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#FF3B3015')
          .borderRadius(8)

        Column() {
          Text('清除缓存')
            .fontSize(16)
            .fontColor('#1A1A1A')
          Text('清除本地消息缓存')
            .fontSize(13)
            .fontColor('#6B6B6B')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .width('100%')
      .height(60)
      .padding({ left: 12, right: 12 })
      .backgroundColor('rgba(255, 255, 255, 0.9)')
      .backdropBlur(20)
      .borderRadius(12)
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  // ==================== 服务商页面 ====================

  @Builder
  ProvidersPage() {
    Column() {
      Scroll() {
        Column() {
          // 标题栏
          Row() {
            Text('服务商')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)

            Button() {
              Text('添加')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#6366F1')
            }
            .width(50)
            .height(36)
            .backgroundColor('transparent')
            .position({ x: '100%', y: 0 })
            .translate({ x: -50 })
          }
          .width('100%')
          .padding({ left: 16, right: 66, top: 60, bottom: 16 })

          // 连接设置
          this.ProviderConnectionSection()

          // 官方认证
          this.OfficialProviderSection()

          // 自定义服务商
          this.CustomProvidersSection()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 100 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ProviderConnectionSection() {
    Column() {
      Text('连接设置')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#6B6B6B')
        .width('100%')
        .margin({ left: 4, bottom: 8 })

      Column() {
        // 配对码
        Row() {
          Column() {
            Text('配对码')
              .fontSize(16)
              .fontColor('#1A1A1A')
            Text('生成配对码连接桌面端')
              .fontSize(13)
              .fontColor('#6B6B6B')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('生成')
            .fontSize(14)
            .fontColor('#6366F1')
        }
        .width('100%')
        .height(52)
        .padding(12)
        .backgroundColor('rgba(255, 255, 255, 0.9)')
        .backdropBlur(20)
        .borderRadius(8)
        .margin({ bottom: 8 })

        // 局域网地址
        Row() {
          Column() {
            Text('局域网地址')
              .fontSize(16)
              .fontColor('#1A1A1A')
            Text('未设置')
              .fontSize(13)
              .fontColor('#6B6B6B')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .height(52)
        .padding(12)
        .backgroundColor('rgba(255, 255, 255, 0.9)')
        .backdropBlur(20)
        .borderRadius(8)
        .margin({ bottom: 8 })

        // 公网隧道
        Row() {
          Column() {
            Text('公网隧道')
              .fontSize(16)
              .fontColor('#1A1A1A')
            Text('未开启')
              .fontSize(13)
              .fontColor('#6B6B6B')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: false })
            .selectedColor('#6366F1')
        }
        .width('100%')
        .height(52)
        .padding(12)
        .backgroundColor('rgba(255, 255, 255, 0.9)')
        .backdropBlur(20)
        .borderRadius(8)
      }
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  @Builder
  OfficialProviderSection() {
    Column() {
      Text('官方认证')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#6B6B6B')
        .width('100%')
        .margin({ left: 4, bottom: 8 })

      Row() {
        Column() {
          Text('Claude Official')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
          Text('使用官方 Anthropic 认证')
            .fontSize(13)
            .fontColor('#6B6B6B')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('当前')
          .fontSize(12)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#6366F1')
          .borderRadius(4)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('rgba(255, 255, 255, 0.9)')
      .backdropBlur(20)
      .borderRadius(12)
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  @Builder
  CustomProvidersSection() {
    Column() {
      Text('自定义服务商')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#6B6B6B')
        .width('100%')
        .margin({ left: 4, bottom: 8 })

      Text('暂无自定义服务商，点击右上角添加')
        .fontSize(15)
        .fontColor('#6B6B6B')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(12)
        .backgroundColor('rgba(255, 255, 255, 0.9)')
        .backdropBlur(20)
        .borderRadius(12)
    }
    .width('100%')
  }
}
