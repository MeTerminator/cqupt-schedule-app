import SwiftUI


struct UserDetailView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    var logout: () -> Void
    @Environment(\.presentationMode) var pm
    
    var body: some View {
        NavigationView {
            List {
                Section("个人信息") {
                    HStack { Text("姓名"); Spacer(); Text(viewModel.scheduleData?.studentName ?? "") }
                    HStack { Text("学号"); Spacer(); Text(viewModel.scheduleData?.studentId ?? "") }
                }
                Section("学期信息") {
                    HStack { Text("学年"); Spacer(); Text(viewModel.scheduleData?.academicYear ?? "") }
                    HStack { Text("学期"); Spacer(); Text("第 \(viewModel.scheduleData?.semester ?? "") 学期") }
                    HStack { Text("开学日期"); Spacer(); Text(String(viewModel.scheduleData?.week1Monday.prefix(10) ?? "")) }
                }
                Button("退出登录", role: .destructive) { logout(); pm.wrappedValue.dismiss() }.frame(maxWidth: .infinity)
            }
            .navigationTitle("用户详情").navigationBarItems(trailing: Button("完成") { pm.wrappedValue.dismiss() })
        }
    }
}