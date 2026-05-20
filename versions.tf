# ──────────────────────────────────────────────────────────────────
# versions.tf  —  Terraform & provider version constraints
#
# FIX: Xoá terraform {} block trùng với providers.tf (Terraform chỉ
# cho phép 1 terraform block per root module).
# Xoá provider "random" và "tls" không được dùng ở bất kỳ module nào.
# ──────────────────────────────────────────────────────────────────
# (File này được giữ lại để tương thích với workflow, nhưng toàn bộ
#  required_version và required_providers đã được khai báo đủ trong
#  providers.tf — không cần khai báo lại ở đây.)
