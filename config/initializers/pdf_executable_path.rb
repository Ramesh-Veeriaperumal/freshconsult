# Dirty Hack to fix wicked_pdf binaries issue in staging/production
# # https://github.com/mileszs/wicked_pdf/issues/266
if Rails.env.staging?
        WickedPdf.config = {
                exe_path: "#{ENV['GEM_HOME']}/gems/wkhtmltopdf-binary-#{Gem.loaded_specs['wkhtmltopdf-binary'].version}/bin/wkhtmltopdf_linux_x64"
        }
end