import SwiftUI


struct LoginView: View {
    @Binding var id: String
    var action: () -> Void
    
    // 适配深色模式的颜色定义
    private var schoolGreen: Color { Color(red: 0.0, green: 0.48, blue: 0.35) }
    private var inputBackground: Color { Color(UIColor.secondarySystemBackground) }
    
    // 校验学号
    private var isValidId: Bool {
        id.count == 10 && id.allSatisfy { $0.isNumber }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 40) {
                // 顶部 Logo
                VStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(schoolGreen.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(schoolGreen)
                    }
                    
                    Text("重邮课表")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        // 使用 primary 会根据深浅模式自动切换黑白
                        .foregroundColor(.primary)
                }
                .padding(.top, 60)
                
                // 输入区域
                VStack(alignment: .leading, spacing: 12) {
                    Text("学号登录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .foregroundColor(schoolGreen)
                        
                        TextField("请输入10位学号", text: $id)
                            .keyboardType(.numberPad)
                            .onChange(of: id) { oldValue, newValue in
                                if newValue.count > 10 {
                                    id = String(newValue.prefix(10))
                                }
                            }
                    }
                    .padding()
                    .background(inputBackground) // 使用系统二级背景色
                    .cornerRadius(15)
                    
                    // 校验提示
                    if !id.isEmpty && !isValidId {
                        Text("学号应为10位数字")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.leading, 4)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, 40)
                
                // 登录按钮
                Button(action: action) {
                    Text("进入课表")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(isValidId ? schoolGreen : Color.gray.opacity(0.3))
                        .cornerRadius(15)
                        .shadow(color: isValidId ? schoolGreen.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                }
                .disabled(!isValidId)
                .frame(maxWidth: 400)
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        // 关键：强制让 ZStack 响应环境变化
        .animation(.easeInOut, value: id)
    }
}