use "cli"
use "crypto"
use "files"
use "net"

actor Main
  """
  CLI entry point. Parses arguments, validates inputs, and
  hands off to the Uploader actor.
  """

  new create(env: Env) =>
    try
      let cs =
        CommandSpec.leaf(
          "cloudsmith-uploader",
          "Upload archives to Cloudsmith",
          [
            OptionSpec.string(
              "version",
              "Package version"
              where short' = 'v')
            OptionSpec.string(
              "api-key",
              "Cloudsmith API key" +
                " (or CLOUDSMITH_API_KEY env var)"
              where short' = 'k', default' = "")
            OptionSpec.string(
              "summary",
              "Package summary"
              where short' = 's')
            OptionSpec.string(
              "description",
              "Package description"
              where short' = 'd')
          ],
          [
            ArgSpec.string(
              "repo",
              "Owner/repo (e.g. ponylang/releases)")
            ArgSpec.string(
              "file",
              "File to upload")
          ])?

      let cmd =
        match \exhaustive\ CommandParser(cs).parse(
          env.args, env.vars)
        | let c: Command => c
        | let ch: CommandHelp =>
          ch.print_help(env.out)
          env.exitcode(0)
          return
        | let se: SyntaxError =>
          env.err.print(se.string())
          env.exitcode(1)
          return
        end

      let version = cmd.option("version").string()
      let summary = cmd.option("summary").string()
      let description =
        cmd.option("description").string()
      let file_path = cmd.arg("file").string()

      let api_key_opt =
        cmd.option("api-key").string()
      let api_key =
        if api_key_opt.size() > 0 then
          api_key_opt
        else
          match EnvVar(env.vars, "CLOUDSMITH_API_KEY")
          | let key: String => key
          else
            env.err.print(
              "error: --api-key not provided and " +
                "CLOUDSMITH_API_KEY not set")
            env.exitcode(1)
            return
          end
        end

      let repo_str = cmd.arg("repo").string()
      let slash_idx =
        try repo_str.find("/")?
        else
          env.err.print(
            "error: repo must be owner/repo " +
              "(e.g. ponylang/releases)")
          env.exitcode(1)
          return
        end
      let owner: String val =
        repo_str.substring(0, slash_idx)
      let repo: String val =
        repo_str.substring(slash_idx + 1)

      if (owner.size() == 0) or
        (repo.size() == 0) or
        repo.contains("/")
      then
        env.err.print(
          "error: repo must be owner/repo " +
            "(e.g. ponylang/releases)")
        env.exitcode(1)
        return
      end

      let file_auth = FileAuth(env.root)
      let fp = FilePath(file_auth, file_path)
      let fi = FileInfo(fp)?
      let file_size = fi.size
      var filename: String val = file_path
      let fwd_parts = file_path.split("/")
      try
        filename = fwd_parts(fwd_parts.size() - 1)?
      end
      let bk_parts = filename.split("\\")
      try
        filename = bk_parts(bk_parts.size() - 1)?
      end

      let tcp_auth = TCPConnectAuth(env.root)
      let ssl_ctx: SSLContext val =
        try
          recover val
            let ctx = SSLContext
            var any_loaded: Bool = false
            ifdef windows then
              try
                ctx.set_authority(None)?
                any_loaded = true
              end
            end
            try
              ctx.set_default_verify_paths()?
              any_loaded = true
            end
            let ca_files =
              [
                "/etc/ssl/cert.pem"
                "/etc/ssl/certs/ca-certificates.crt"
                "/etc/pki/tls/certs/ca-bundle.crt"
                "/etc/ssl/ca-bundle.pem"
              ]
            for ca_file in ca_files.values() do
              try
                ctx.set_authority(
                  FilePath(file_auth, ca_file))?
                any_loaded = true
              end
            end
            if not any_loaded then error end
            ctx
          end
        else
          env.err.print(
            "error: failed to load system " +
              "CA certificates")
          env.exitcode(1)
          return
        end

      let digest = Digest.md5()?
      let md5_file = File.open(fp)
      if not (md5_file.errno() is FileOK) then
        env.err.print(
          "error: cannot open file: " + file_path)
        env.exitcode(1)
        return
      end
      var md5_read_ok: Bool = true
      while md5_file.errno() is FileOK do
        let chunk: Array[U8] val =
          md5_file.read(1_048_576)
        if chunk.size() == 0 then break end
        if not (md5_file.errno() is FileOK) then
          md5_read_ok = false
          break
        end
        digest.append(chunk)?
      end
      md5_file.dispose()
      if not md5_read_ok then
        env.err.print(
          "error: I/O error reading file: " +
            file_path)
        env.exitcode(1)
        return
      end
      let md5_hex = ToHexString(digest.final()?)

      env.err.print(
        "uploading " + filename +
          " (" + file_size.string() + " bytes, " +
          "md5=" + md5_hex + ")")

      Uploader(
        env,
        tcp_auth,
        ssl_ctx,
        file_auth,
        api_key,
        owner,
        repo,
        version,
        summary,
        description,
        file_path,
        filename,
        md5_hex)
    else
      env.err.print("error: failed to initialize")
      env.exitcode(1)
    end
