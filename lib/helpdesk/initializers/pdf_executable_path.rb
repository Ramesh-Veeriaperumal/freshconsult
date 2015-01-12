# Dirty Hack to fix wicked_pdf binaries issue in staging/production
# # https://github.com/mileszs/wicked_pdf/issues/266
if Rails.env.staging? || Rails.env.production?
        WickedPdf.config = {
                exe_path: "#{Gem.loaded_specs['wkhtmltopdf-binary'].full_gem_path}/bin/wkhtmltopdf_linux_amd64"
        }
end