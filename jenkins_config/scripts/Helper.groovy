import org.yaml.snakeyaml.Yaml

class Helper {
  static final String SCM_DOMAIN = "http://k8s-gitlab-gitlabwe-11c16d8044-709872649.ap-southeast-1.elb.amazonaws.com"
  static final String MANIFEST_DIRECTORY = "job-dsl/manifests"
  static final String DEFAULT_SINGLE_BRANCH = "main"
  static final String DEFAULT_MULTIPLE_BRANCH = "((main)|(develop)|(release/.*))"
  static final String DEFAULT_SCRIPT_PATH = "Jenkinsfile"
  static final String SCM_CREDENTIAL_ID = "gitlab-credentials"

  static def readManifest(self, String fileName) {
    def filePath = "${MANIFEST_DIRECTORY}/${fileName}.yaml"
    def fileContent = self.readFileFromWorkspace(filePath)
    def manifest = new Yaml().load(fileContent)
    return manifest
  }

  static void createFolder(self, String folderName, String folderPath) {
    self.folder(folderPath) {
      displayName(folderName)
      description("Folder for ${folderName}")
    }
  }

  static void createSingleBranchJob(self, def job, String jobPath) {
    self.pipelineJob(jobPath) {
      displayName(job.name)
      definition {
        cpsScm {
          scriptPath(job.script_path ?: DEFAULT_SCRIPT_PATH)
          scm {
            git {
              remote {
                url("${SCM_DOMAIN}/${job.git_path}")
                credentials(SCM_CREDENTIAL_ID)
              }
              branch(job.branch ?: DEFAULT_SINGLE_BRANCH)
            }
          }
        }
      }
    }
  }

  static void createMultipleBranchJob(self, def job, String jobPath) {
    self.multibranchPipelineJob(jobPath) {
      displayName(job.name)
      factory {
        workflowBranchProjectFactory {
          scriptPath(job.script_path ?: DEFAULT_SCRIPT_PATH)
        }
      }
      branchSources {
        git {
          remote("${SCM_DOMAIN}/${job.git_path}")
          credentialsId(SCM_CREDENTIAL_ID)
          includes(job.branch ?: DEFAULT_MULTIPLE_BRANCH)
        }
      }
    }
  }
}
